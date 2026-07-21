import { HttpStatus } from "@nestjs/common";

export class DomainException extends Error {
  constructor(
    readonly code: string,
    message: string,
    readonly status: HttpStatus = HttpStatus.BAD_REQUEST,
    readonly details: Record<string, unknown> = {}
  ) {
    super(message);
    this.name = "DomainException";
  }
}

