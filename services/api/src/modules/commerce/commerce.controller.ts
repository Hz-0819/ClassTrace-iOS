import { Body, Controller, Get, Param, Post, UseGuards } from "@nestjs/common";
import { AuthGuard } from "../../common/auth/auth.guard";
import { AuthenticatedUser } from "../../common/auth/authenticated-user";
import { CurrentUser } from "../../common/auth/current-user.decorator";
import { Roles, RolesGuard } from "../../common/auth/roles.guard";
import { AppStoreService } from "./app-store.service";
import { CommerceService } from "./commerce.service";
import { CreateActivationCodeDto, CreateOrderDto, RecordPaymentDto, RedeemActivationCodeDto, RequestRefundDto, ResolveRefundDto, StoreKitNotificationDto, StoreKitTransactionDto } from "./commerce.dto";

@Controller()
@UseGuards(AuthGuard, RolesGuard)
export class CommerceController {
  constructor(private readonly commerce: CommerceService, private readonly appStore: AppStoreService) {}
  @Get("orders") orders(@CurrentUser() u: AuthenticatedUser) { return this.commerce.listOrders(u.id); }
  @Get("orders/stats") stats(@CurrentUser() u: AuthenticatedUser) { return this.commerce.stats(u.id); }
  @Get("orders/:id") order(@CurrentUser() u: AuthenticatedUser, @Param("id") id: string) { return this.commerce.order(u.id, id); }
  @Post("orders") create(@CurrentUser() u: AuthenticatedUser, @Body() d: CreateOrderDto) { return this.commerce.createOrder(u.id, d); }
  @Post("orders/:id/payments") payment(@CurrentUser() u: AuthenticatedUser, @Param("id") id: string, @Body() d: RecordPaymentDto) { return this.commerce.recordPayment(u.id, id, d); }
  @Post("orders/:id/refunds") refund(@CurrentUser() u: AuthenticatedUser, @Param("id") id: string, @Body() d: RequestRefundDto) { return this.commerce.requestRefund(u.id, id, d); }
  @Post("refunds/:id/resolve") resolve(@CurrentUser() u: AuthenticatedUser, @Param("id") id: string, @Body() d: ResolveRefundDto) { return this.commerce.resolveRefund(u.id, id, d); }
  @Post("storekit/transactions") transaction(@CurrentUser() u: AuthenticatedUser, @Body() d: StoreKitTransactionDto) { return this.appStore.verifyTransaction(u.id, d.signedTransaction); }
  @Get("entitlements") entitlements(@CurrentUser() u: AuthenticatedUser) { return this.appStore.entitlements(u.id); }
  @Post("activation-codes") @Roles("ADMIN") activation(@CurrentUser() u: AuthenticatedUser, @Body() d: CreateActivationCodeDto) { return this.appStore.createActivationCode(u.id, d.days); }
  @Post("activation-codes/redeem") redeem(@CurrentUser() u: AuthenticatedUser, @Body() d: RedeemActivationCodeDto) { return this.appStore.redeemActivationCode(u.id, d.code); }
}

@Controller("webhooks/app-store")
export class AppStoreWebhookController {
  constructor(private readonly appStore: AppStoreService) {}
  @Post() notification(@Body() d: StoreKitNotificationDto) { return this.appStore.processNotification(d.signedPayload); }
}
