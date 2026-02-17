type TokenType = "identifier" | "number" | "string" | "boolean" | "null" | "operator" | "lparen" | "rparen" | "eof";

interface Token {
  type: TokenType;
  value: string;
}

const TWO_CHAR_OPERATORS = new Set(["&&", "||", "==", "!=", ">=", "<="]);
const THREE_CHAR_OPERATORS = new Set(["===", "!=="]);
const ONE_CHAR_OPERATORS = new Set(["!", ">", "<"]);

class Tokenizer {
  private index = 0;

  constructor(private readonly input: string) {}

  tokenize(): Token[] {
    const tokens: Token[] = [];
    while (true) {
      this.skipWhitespace();
      if (this.index >= this.input.length) {
        tokens.push({ type: "eof", value: "" });
        return tokens;
      }

      const char = this.input[this.index];
      if (!char) {
        tokens.push({ type: "eof", value: "" });
        return tokens;
      }

      if (char === "(") {
        this.index += 1;
        tokens.push({ type: "lparen", value: "(" });
        continue;
      }

      if (char === ")") {
        this.index += 1;
        tokens.push({ type: "rparen", value: ")" });
        continue;
      }

      if (char === "'" || char === "\"") {
        tokens.push({ type: "string", value: this.readString(char) });
        continue;
      }

      if (this.isDigit(char)) {
        tokens.push({ type: "number", value: this.readNumber() });
        continue;
      }

      const op = this.readOperator();
      if (op) {
        tokens.push({ type: "operator", value: op });
        continue;
      }

      if (this.isIdentifierStart(char)) {
        const value = this.readIdentifier();
        if (value === "true" || value === "false") {
          tokens.push({ type: "boolean", value });
          continue;
        }
        if (value === "null") {
          tokens.push({ type: "null", value });
          continue;
        }
        tokens.push({ type: "identifier", value });
        continue;
      }

      throw new Error(`Unsupported token at index ${this.index}`);
    }
  }

  private skipWhitespace(): void {
    while (this.index < this.input.length && /\s/.test(this.input[this.index] ?? "")) {
      this.index += 1;
    }
  }

  private isDigit(char: string): boolean {
    return char >= "0" && char <= "9";
  }

  private readNumber(): string {
    const start = this.index;
    while (this.index < this.input.length && this.isDigit(this.input[this.index] ?? "")) {
      this.index += 1;
    }

    if ((this.input[this.index] ?? "") === ".") {
      this.index += 1;
      while (this.index < this.input.length && this.isDigit(this.input[this.index] ?? "")) {
        this.index += 1;
      }
    }

    return this.input.slice(start, this.index);
  }

  private readString(quote: "'" | "\""): string {
    this.index += 1;
    let value = "";

    while (this.index < this.input.length) {
      const char = this.input[this.index];
      if (!char) break;
      if (char === "\\") {
        const next = this.input[this.index + 1];
        if (!next) {
          throw new Error("Invalid string escape");
        }
        if (next === "n") value += "\n";
        else if (next === "t") value += "\t";
        else value += next;
        this.index += 2;
        continue;
      }
      if (char === quote) {
        this.index += 1;
        return value;
      }
      value += char;
      this.index += 1;
    }

    throw new Error("Unterminated string literal");
  }

  private readOperator(): string | null {
    const three = this.input.slice(this.index, this.index + 3);
    if (THREE_CHAR_OPERATORS.has(three)) {
      this.index += 3;
      return three;
    }
    const two = this.input.slice(this.index, this.index + 2);
    if (TWO_CHAR_OPERATORS.has(two)) {
      this.index += 2;
      return two;
    }
    const one = this.input[this.index] ?? "";
    if (ONE_CHAR_OPERATORS.has(one)) {
      this.index += 1;
      return one;
    }
    return null;
  }

  private isIdentifierStart(char: string): boolean {
    return /[A-Za-z_]/.test(char);
  }

  private readIdentifier(): string {
    const start = this.index;
    while (this.index < this.input.length && /[A-Za-z0-9_.:-]/.test(this.input[this.index] ?? "")) {
      this.index += 1;
    }
    return this.input.slice(start, this.index);
  }
}

class Parser {
  private index = 0;

  constructor(
    private readonly tokens: Token[],
    private readonly context: Record<string, unknown>,
  ) {}

  parse(): boolean {
    const value = this.parseOrExpression();
    this.expect("eof");
    return Boolean(value);
  }

  private parseOrExpression(): unknown {
    let left = this.parseAndExpression();
    while (this.matchOperator("||")) {
      left = Boolean(left) || Boolean(this.parseAndExpression());
    }
    return left;
  }

  private parseAndExpression(): unknown {
    let left = this.parseEqualityExpression();
    while (this.matchOperator("&&")) {
      left = Boolean(left) && Boolean(this.parseEqualityExpression());
    }
    return left;
  }

  private parseEqualityExpression(): unknown {
    let left = this.parseRelationalExpression();

    while (true) {
      if (this.matchOperator("==") || this.matchOperator("===")) {
        left = left === this.parseRelationalExpression();
        continue;
      }
      if (this.matchOperator("!=") || this.matchOperator("!==")) {
        left = left !== this.parseRelationalExpression();
        continue;
      }
      return left;
    }
  }

  private parseRelationalExpression(): unknown {
    let left = this.parseUnaryExpression();
    while (true) {
      if (this.matchOperator(">")) {
        left = this.toNumber(left) > this.toNumber(this.parseUnaryExpression());
        continue;
      }
      if (this.matchOperator(">=")) {
        left = this.toNumber(left) >= this.toNumber(this.parseUnaryExpression());
        continue;
      }
      if (this.matchOperator("<")) {
        left = this.toNumber(left) < this.toNumber(this.parseUnaryExpression());
        continue;
      }
      if (this.matchOperator("<=")) {
        left = this.toNumber(left) <= this.toNumber(this.parseUnaryExpression());
        continue;
      }
      return left;
    }
  }

  private parseUnaryExpression(): unknown {
    if (this.matchOperator("!")) {
      return !Boolean(this.parseUnaryExpression());
    }
    return this.parsePrimary();
  }

  private parsePrimary(): unknown {
    const token = this.peek();
    if (!token) {
      throw new Error("Unexpected end of expression");
    }

    if (token.type === "lparen") {
      this.index += 1;
      const value = this.parseOrExpression();
      this.expect("rparen");
      return value;
    }

    if (token.type === "number") {
      this.index += 1;
      return Number(token.value);
    }

    if (token.type === "string") {
      this.index += 1;
      return token.value;
    }

    if (token.type === "boolean") {
      this.index += 1;
      return token.value === "true";
    }

    if (token.type === "null") {
      this.index += 1;
      return null;
    }

    if (token.type === "identifier") {
      this.index += 1;
      return this.resolveIdentifier(token.value);
    }

    throw new Error(`Unexpected token ${token.type}`);
  }

  private resolveIdentifier(identifier: string): unknown {
    const normalized = identifier.startsWith("context.") ? identifier.slice("context.".length) : identifier;
    if (normalized in this.context) {
      return this.context[normalized];
    }

    const segments = normalized.split(".");
    let current: unknown = this.context;
    for (const segment of segments) {
      if (!segment) {
        return undefined;
      }
      if (current && typeof current === "object" && segment in (current as Record<string, unknown>)) {
        current = (current as Record<string, unknown>)[segment];
        continue;
      }
      return undefined;
    }
    return current;
  }

  private toNumber(value: unknown): number {
    if (typeof value === "number") return value;
    if (typeof value === "string" && value.trim()) {
      const parsed = Number(value);
      if (Number.isFinite(parsed)) return parsed;
    }
    throw new Error("Relational operators require numeric operands");
  }

  private matchOperator(op: string): boolean {
    const token = this.peek();
    if (!token || token.type !== "operator" || token.value !== op) {
      return false;
    }
    this.index += 1;
    return true;
  }

  private expect(type: TokenType): void {
    const token = this.peek();
    if (!token || token.type !== type) {
      throw new Error(`Expected ${type}`);
    }
    this.index += 1;
  }

  private peek(): Token | undefined {
    return this.tokens[this.index];
  }
}

export function evaluateSafeCondition(expression: string, context: Record<string, unknown>): boolean {
  const tokens = new Tokenizer(expression).tokenize();
  return new Parser(tokens, context).parse();
}
