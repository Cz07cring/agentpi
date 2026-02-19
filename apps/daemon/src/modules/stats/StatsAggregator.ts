export interface SessionUsageStats {
  input: number;
  output: number;
  cacheRead: number;
  cacheWrite: number;
  totalTokens: number;
  cost: number;
  activeDays: Set<string>;
}

export class StatsAggregator {
  private readonly stats = new Map<string, SessionUsageStats>();

  private ensure(sessionId: string): SessionUsageStats {
    const existing = this.stats.get(sessionId);
    if (existing) return existing;

    const created: SessionUsageStats = {
      input: 0,
      output: 0,
      cacheRead: 0,
      cacheWrite: 0,
      totalTokens: 0,
      cost: 0,
      activeDays: new Set<string>(),
    };
    this.stats.set(sessionId, created);
    return created;
  }

  onSessionEvent(sessionId: string, event: Record<string, unknown>): void {
    const stats = this.ensure(sessionId);
    stats.activeDays.add(new Date().toISOString().slice(0, 10));

    const maybeMessage = event.message as { usage?: Record<string, unknown> } | undefined;
    const usage = maybeMessage?.usage;
    if (!usage) return;

    const safeNum = (v: unknown): number => {
      const n = Number(v ?? 0);
      return Number.isFinite(n) ? n : 0;
    };

    stats.input += safeNum(usage.input);
    stats.output += safeNum(usage.output);
    stats.cacheRead += safeNum(usage.cacheRead);
    stats.cacheWrite += safeNum(usage.cacheWrite);
    stats.totalTokens += safeNum(usage.totalTokens);
    const cost = usage.cost as Record<string, unknown> | undefined;
    if (cost) {
      stats.cost += safeNum(cost.total);
    }
  }

  removeSession(sessionId: string): void {
    this.stats.delete(sessionId);
  }

  getSessionStats(sessionId: string): Omit<SessionUsageStats, "activeDays"> & { activeDays: number } {
    const stats = this.ensure(sessionId);
    return {
      input: stats.input,
      output: stats.output,
      cacheRead: stats.cacheRead,
      cacheWrite: stats.cacheWrite,
      totalTokens: stats.totalTokens,
      cost: stats.cost,
      activeDays: stats.activeDays.size,
    };
  }
}
