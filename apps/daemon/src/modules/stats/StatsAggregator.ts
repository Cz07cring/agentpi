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

    stats.input += Number(usage.input ?? 0);
    stats.output += Number(usage.output ?? 0);
    stats.cacheRead += Number(usage.cacheRead ?? 0);
    stats.cacheWrite += Number(usage.cacheWrite ?? 0);
    stats.totalTokens += Number(usage.totalTokens ?? 0);
    const cost = usage.cost as Record<string, unknown> | undefined;
    if (cost) {
      stats.cost += Number(cost.total ?? 0);
    }
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
