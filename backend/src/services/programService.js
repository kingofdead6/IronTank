import { Exercise } from '../models/Exercise.js';
import { Program } from '../models/Program.js';
import { WorkoutSession } from '../models/WorkoutSession.js';
import { AppError } from '../utils/AppError.js';
import { paginate } from '../utils/pagination.js';

const EXERCISE_SUMMARY = 'name images primaryMuscles equipment category isBodyweight';

const visibleTo = (userId) => ({ $or: [{ isTemplate: true }, { userId }] });

/**
 * Serialises a program with each planned exercise's summary inlined as
 * `exercise`, keeping `exerciseId` as a plain string.
 */
function serialize(program) {
  const json = program.toJSON();
  json.days = json.days.map((day) => ({
    id: day._id.toString(),
    name: day.name,
    exercises: day.exercises.map(({ _id, exerciseId, ...rest }) => {
      const populated = exerciseId && typeof exerciseId === 'object' && exerciseId.name !== undefined;
      return {
        id: _id.toString(),
        exerciseId: populated ? exerciseId.id ?? exerciseId._id.toString() : exerciseId.toString(),
        exercise: populated
          ? {
              id: exerciseId.id ?? exerciseId._id.toString(),
              name: exerciseId.name,
              image: exerciseId.images?.[0] ?? null,
              primaryMuscles: exerciseId.primaryMuscles,
              equipment: exerciseId.equipment,
              category: exerciseId.category,
              isBodyweight: exerciseId.isBodyweight,
            }
          : null,
        ...rest,
      };
    }),
  }));
  return json;
}

const populateExercises = { path: 'days.exercises.exerciseId', select: EXERCISE_SUMMARY };

async function assertExercisesVisible(userId, days) {
  const ids = [...new Set(days.flatMap((d) => d.exercises.map((e) => e.exerciseId.toString())))];
  const count = await Exercise.countDocuments({
    _id: { $in: ids },
    $or: [{ createdBy: null }, { createdBy: userId }],
  });
  if (count !== ids.length) throw new AppError(422, 'UNKNOWN_EXERCISE', 'One or more exercises do not exist');
}

function assertRepRanges(days) {
  for (const day of days) {
    for (const ex of day.exercises) {
      if (ex.repRange && ex.repRange.min > ex.repRange.max) {
        throw AppError.validation([{ path: 'body.days.exercises.repRange', message: 'min must be ≤ max' }]);
      }
    }
  }
}

export async function listPrograms(userId, { scope, page, limit }) {
  const filter =
    scope === 'mine' ? { userId } : scope === 'templates' ? { isTemplate: true } : visibleTo(userId);
  const result = await paginate(Program, filter, {
    page,
    limit,
    sort: { isActive: -1, isTemplate: 1, updatedAt: -1, _id: 1 },
    populate: populateExercises,
  });
  return { ...result, data: result.data.map(serialize) };
}

async function loadVisible(userId, id) {
  const program = await Program.findOne({ _id: id, ...visibleTo(userId) });
  if (!program) throw AppError.notFound('Program');
  return program;
}

async function loadOwned(userId, id) {
  const program = await Program.findById(id);
  if (!program || (!program.isTemplate && program.userId?.toString() !== userId.toString())) {
    throw AppError.notFound('Program');
  }
  if (program.isTemplate) throw AppError.forbidden('Built-in templates cannot be modified; clone it first');
  return program;
}

export async function getProgram(userId, id) {
  const program = await loadVisible(userId, id);
  await program.populate(populateExercises);
  return serialize(program);
}

export async function createProgram(userId, data) {
  assertRepRanges(data.days ?? []);
  await assertExercisesVisible(userId, data.days ?? []);
  const program = await Program.create({ ...data, userId, isTemplate: false, isActive: false });
  return getProgram(userId, program._id);
}

export async function updateProgram(userId, id, data) {
  const program = await loadOwned(userId, id);
  if (data.days) {
    assertRepRanges(data.days);
    await assertExercisesVisible(userId, data.days);
  }
  program.set(data);
  await program.save();
  return getProgram(userId, id);
}

export async function deleteProgram(userId, id) {
  const program = await loadOwned(userId, id);
  await program.deleteOne();
}

/** Copies a template (or one of the user's own programs) into the user's programs. */
export async function cloneProgram(userId, id) {
  const source = await loadVisible(userId, id);
  const plain = source.toObject();
  const copy = await Program.create({
    userId,
    name: source.isTemplate ? plain.name : `${plain.name} (copy)`,
    description: plain.description,
    weeks: plain.weeks,
    // New subdocument ids so day references don't collide with the source.
    days: plain.days.map(({ _id, exercises, ...day }) => ({
      ...day,
      exercises: exercises.map(({ _id: _e, ...ex }) => ex),
    })),
    isTemplate: false,
    sourceTemplateId: source.isTemplate ? source._id : source.sourceTemplateId,
  });
  return getProgram(userId, copy._id);
}

/**
 * Makes a program the user's active one. Activating a template first clones it,
 * so the user can tweak their copy without affecting the built-in version.
 */
export async function activateProgram(userId, id) {
  const target = await loadVisible(userId, id);
  const programId = target.isTemplate ? (await cloneProgram(userId, id)).id : target._id;

  // Deactivate first: the partial unique index allows only one active program.
  await Program.updateMany({ userId, isActive: true }, { $set: { isActive: false } });
  await Program.updateOne({ _id: programId }, { $set: { isActive: true, activatedAt: new Date() } });
  return getProgram(userId, programId);
}

export async function deactivateProgram(userId) {
  await Program.updateMany({ userId, isActive: true }, { $set: { isActive: false } });
}

/**
 * The active program plus the day to train next: days rotate in order,
 * continuing after the last completed session that used this program.
 */
export async function activeProgramWithNextDay(userId) {
  const program = await Program.findOne({ userId, isActive: true }).populate(populateExercises);
  if (!program) return { program: null, nextDay: null, lastSession: null };

  const serialized = serialize(program);
  if (!program.days.length) return { program: serialized, nextDay: null, lastSession: null };

  const last = await WorkoutSession.findOne({ userId, status: 'completed', programId: program._id })
    .sort({ startedAt: -1 })
    .select('dayId startedAt name')
    .lean();

  let index = 0;
  if (last?.dayId) {
    const lastIndex = program.days.findIndex((d) => d._id.toString() === last.dayId.toString());
    if (lastIndex >= 0) index = (lastIndex + 1) % program.days.length;
  }

  return {
    program: serialized,
    nextDay: { index, ...serialized.days[index] },
    lastSession: last ? { id: last._id.toString(), dayId: last.dayId?.toString() ?? null, startedAt: last.startedAt } : null,
  };
}
