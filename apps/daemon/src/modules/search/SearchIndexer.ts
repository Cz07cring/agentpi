import type { PersistenceStore } from "../storage/PersistenceStore.js";

export class SearchIndexer {
  constructor(private readonly store: PersistenceStore) {}

  indexSessionText(sessionId: string, textValue: string, filePath: string | null = null): void {
    if (!textValue.trim()) return;
    this.store.indexSearchEntry(sessionId, textValue, filePath);
  }

  search(query: string, limit = 50): Array<{ sessionId: string; text: string; filePath: string | null }> {
    return this.store.search(query, limit);
  }
}
