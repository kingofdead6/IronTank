import { effectiveLoad, epley, MAX_E1RM_REPS, setE1rm } from '../../src/services/oneRepMax.js';

describe('epley', () => {
  it('applies weight × (1 + reps/30)', () => {
    expect(epley(100, 5)).toBe(116.7);
    expect(epley(100, 10)).toBe(133.3);
    expect(epley(60, 12)).toBe(84);
  });

  it('returns the weight itself for a single rep', () => {
    expect(epley(140, 1)).toBe(140);
  });

  it(`ignores sets above ${MAX_E1RM_REPS} reps`, () => {
    expect(epley(50, 13)).toBeNull();
    expect(epley(50, 30)).toBeNull();
  });

  it('rejects zero/negative/invalid input', () => {
    expect(epley(0, 5)).toBeNull();
    expect(epley(-10, 5)).toBeNull();
    expect(epley(100, 0)).toBeNull();
    expect(epley(Number.NaN, 5)).toBeNull();
  });
});

describe('effectiveLoad / setE1rm', () => {
  const barbell = { isBodyweight: false };
  const pullup = { isBodyweight: true };

  it('uses the logged weight for loaded exercises', () => {
    expect(effectiveLoad(100, barbell, 80)).toBe(100);
  });

  it('adds bodyweight for bodyweight exercises (negative = assistance)', () => {
    expect(effectiveLoad(20, pullup, 80)).toBe(100);
    expect(effectiveLoad(0, pullup, 80)).toBe(80);
    expect(effectiveLoad(-20, pullup, 80)).toBe(60);
  });

  it('computes e1RM on effective load', () => {
    expect(setE1rm({ weight: 20, reps: 5 }, pullup, 80)).toBe(116.7);
    expect(setE1rm({ weight: 100, reps: 5 }, barbell, 80)).toBe(116.7);
  });
});
