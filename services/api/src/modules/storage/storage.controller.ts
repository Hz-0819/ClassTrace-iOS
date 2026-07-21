import { Body, Controller, Get, Post, Query, UseGuards } from "@nestjs/common";
import { AuthGuard } from "../../common/auth/auth.guard";
import { AuthenticatedUser } from "../../common/auth/authenticated-user";
import { CurrentUser } from "../../common/auth/current-user.decorator";
import { UploadIntentDto } from "./storage.dto";
import { StorageService } from "./storage.service";
@Controller("storage") @UseGuards(AuthGuard)
export class StorageController {
  constructor(private readonly storage: StorageService) {}
  @Post("upload-intents") upload(@CurrentUser() u: AuthenticatedUser, @Body() d: UploadIntentDto) { return this.storage.createUploadIntent(u.id, d.fileName, d.mimeType, d.sizeBytes); }
  @Get("download-url") download(@CurrentUser() u: AuthenticatedUser, @Query("objectKey") objectKey: string) { return this.storage.downloadUrl(u.id, objectKey); }
}
