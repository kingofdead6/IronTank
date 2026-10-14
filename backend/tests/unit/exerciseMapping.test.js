import { metFor } from '../../src/config/metTable.js';
import { mapSourceExercise, slugify } from '../../src/services/exerciseService.js';
import { sampleSource } from '../helpers/fixtures.js';

const byId = (id) => sampleSource.find((e) => e.id === id);

describe('slugify', () => {
  it('produces url-safe lowercase slugs', () => {
    expect(slugify('Barbell_Bench_Press_-_Medium_Grip')).toBe('barbell-bench-press-medium-grip');
    expect(slugify('  Crème Brûlée Curl!! ')).toBe('creme-brulee-curl');
  });
});

describe('mapSourceExercise', () => {
  it('maps core fields and builds raw GitHub image URLs', () => {
    const ex = mapSourceExercise(byId('Barbell_Bench_Press_-_Medium_Grip'));
    expect(ex).toMatchObject({
      name: 'Barbell Bench Press - Medium Grip',
      slug: 'barbell-bench-press-medium-grip',
      category: 'strength',
      equipment: 'barbell',
      liftKey: 'bench_press',
      isBodyweight: false,
      isCustom: false,
      createdBy: null,
    });
    expect(ex.primaryMuscles).toContain('chest');
    expect(ex.images[0]).toBe(
      'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Bench_Press_-_Medium_Grip/0.jpg',
    );
    expect(ex.instructions.length).toBeGreaterThan(0);
  });

  it('flags bodyweight lifts and links them to ranked lifts', () => {
    const pullup = mapSourceExercise(byId('Pullups'));
    expect(pullup.isBodyweight).toBe(true);
    expect(pullup.liftKey).toBe('pull_up');
    expect(mapSourceExercise(byId('Dips_-_Triceps_Version')).liftKey).toBe('dips');
  });

  it('collapses dataset categories into strength/cardio/stretching', () => {
    expect(mapSourceExercise(byId('Hamstring_Stretch')).category).toBe('stretching');
    expect(mapSourceExercise(byId('Rope_Jumping')).category).toBe('cardio');
    expect(mapSourceExercise({ id: 'X', name: 'X', category: 'powerlifting' }).category).toBe('strength');
    expect(mapSourceExercise({ id: 'Y', name: 'Y', category: 'plyometrics' }).category).toBe('cardio');
  });

  it('normalises missing or unknown equipment', () => {
    expect(mapSourceExercise({ id: 'A', name: 'A', category: 'strength', equipment: null }).equipment).toBe('none');
    expect(mapSourceExercise({ id: 'B', name: 'B', category: 'strength', equipment: 'sled' }).equipment).toBe('other');
  });
});

describe('metFor', () => {
  it('uses source category for non-generic categories', () => {
    expect(metFor({ category: 'stretching', sourceCategory: 'stretching', equipment: 'none' })).toBe(2.3);
    expect(metFor({ category: 'cardio', sourceCategory: 'plyometrics', equipment: 'body only' })).toBe(8);
  });

  it('uses equipment for general strength work', () => {
    expect(metFor({ category: 'strength', sourceCategory: 'strength', equipment: 'barbell' })).toBe(6);
    expect(metFor({ category: 'strength', sourceCategory: 'strength', equipment: 'machine' })).toBe(4);
  });

  it('falls back to a category default', () => {
    expect(metFor({ category: 'cardio' })).toBe(7);
    expect(metFor({ category: 'strength', equipment: 'unknown' })).toBe(5);
  });
});
