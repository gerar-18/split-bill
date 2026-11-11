import { of } from 'rxjs';
import { ExecutionContext, CallHandler } from '@nestjs/common';
import { BigIntInterceptor, transformBigInt } from './bigint.interceptor';

describe('BigInt Serialization', () => {
  it('converts BigInt within safe integer range to Number', () => {
    const input = {
      amount: BigInt(1250),
      nested: {
        total: BigInt(999999),
      },
    };

    const result = transformBigInt(input) as { amount: number; nested: { total: number } };
    expect(result.amount).toBe(1250);
    expect(typeof result.amount).toBe('number');
    expect(result.nested.total).toBe(999999);
    expect(typeof result.nested.total).toBe('number');
  });

  it('converts BigInt beyond MAX_SAFE_INTEGER to string', () => {
    const huge = BigInt('9007199254740992');
    const result = transformBigInt({ huge }) as { huge: string };
    expect(result.huge).toBe('9007199254740992');
    expect(typeof result.huge).toBe('string');
  });

  it('converts BigInt lower than MIN_SAFE_INTEGER to string', () => {
    const negativeHuge = BigInt('-9007199254740992');
    const result = transformBigInt({ negativeHuge }) as { negativeHuge: string };
    expect(result.negativeHuge).toBe('-9007199254740992');
    expect(typeof result.negativeHuge).toBe('string');
  });

  it('handles zero, boundary MAX_SAFE_INTEGER and MIN_SAFE_INTEGER as numbers', () => {
    const boundaries = {
      zero: BigInt(0),
      maxSafe: BigInt(Number.MAX_SAFE_INTEGER),
      minSafe: BigInt(Number.MIN_SAFE_INTEGER),
    };
    const result = transformBigInt(boundaries) as {
      zero: number;
      maxSafe: number;
      minSafe: number;
    };
    expect(result.zero).toBe(0);
    expect(typeof result.zero).toBe('number');
    expect(result.maxSafe).toBe(Number.MAX_SAFE_INTEGER);
    expect(typeof result.maxSafe).toBe('number');
    expect(result.minSafe).toBe(Number.MIN_SAFE_INTEGER);
    expect(typeof result.minSafe).toBe('number');
  });

  it('handles null, undefined, primitive strings, booleans, and numbers unchanged', () => {
    expect(transformBigInt(null)).toBeNull();
    expect(transformBigInt(undefined)).toBeUndefined();
    expect(transformBigInt('hello')).toBe('hello');
    expect(transformBigInt(42)).toBe(42);
    expect(transformBigInt(true)).toBe(true);
    expect(transformBigInt(false)).toBe(false);
  });

  it('preserves dates and arrays recursively', () => {
    const date = new Date('2026-11-11T12:00:00.000Z');
    const input = [
      BigInt(100),
      date,
      'hello',
      [BigInt(200), { key: BigInt(300) }],
    ];
    const result = transformBigInt(input);
    expect(result).toEqual([
      100,
      date.toISOString(),
      'hello',
      [200, { key: 300 }],
    ]);
  });

  describe('BigIntInterceptor class integration', () => {
    it('intercepts execution and transforms response body stream', (done) => {
      const interceptor = new BigIntInterceptor();
      const mockContext = {} as ExecutionContext;
      const mockCallHandler: CallHandler = {
        handle: () => of({ totalCents: BigInt(12500), items: [{ price: BigInt(500) }] }),
      };

      interceptor.intercept(mockContext, mockCallHandler).subscribe({
        next: (val) => {
          expect(val).toEqual({
            totalCents: 12500,
            items: [{ price: 500 }],
          });
          done();
        },
        error: done,
      });
    });
  });
});
