export interface UpdateUserStatusDto {
  is_active: boolean;
}

export interface UpdateTariffDto {
  base_cost_per_play: number;
  subscription_cost: number;
  discount_percentage: number;
  min_plays_for_discount: number;
}

export interface CreateBankAccountDto {
  bank_name: string;
  account_number: string;
  account_type: string;
  account_holder: string;
  description?: string;
}

export interface UpdateBankAccountDto extends CreateBankAccountDto {}

export interface CreateMessageDto {
  title: string;
  body: string;
  message_type: string;
  role: 'sender' | 'receiver' | 'general';
  is_active?: boolean;
}

export interface UpdateMessageDto extends CreateMessageDto {}

export interface UpdateOAuthProviderDto {
  client_id: string;
  client_secret: string;
  redirect_uri: string;
  is_active: boolean;
}

export interface ToggleStatusDto {
  is_active: boolean;
}
