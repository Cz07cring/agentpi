import { EventEmitter } from "node:events";
import type { WsEvent } from "@agentpi/protocol";

export class DaemonEventBus extends EventEmitter {
  emitWs(event: WsEvent): void {
    this.emit("ws", event);
  }

  onWs(listener: (event: WsEvent) => void): () => void {
    this.on("ws", listener);
    return () => this.off("ws", listener);
  }
}
