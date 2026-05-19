class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :trackable, :confirmable, :lockable

  pay_customer

  enum :plan, { basic: 0, pro: 1 }

  # Ransack 4 requires explicit allowlists for every AA-registered model.
  # The omitted fields are auth secrets (encrypted_password, *_token) or
  # things that leak in-flight account state (unconfirmed_email, *_ip).
  def self.ransackable_attributes(_auth_object = nil)
    %w[id email plan confirmed_at created_at updated_at current_sign_in_at last_sign_in_at sign_in_count failed_attempts locked_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[pay_customers]
  end
end
