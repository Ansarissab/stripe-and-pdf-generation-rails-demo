class AdminUser < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable and :omniauthable
  devise :database_authenticatable,
         :recoverable, :rememberable, :validatable,
         :trackable, :lockable, :timeoutable

  def to_s
    email
  end

  # Ransack 4 requires explicit allowlists for every AA-registered model.
  # Auth secrets (encrypted_password, *_token) and sign-in IPs deliberately
  # excluded so they cannot be filtered / sorted through admin URLs.
  def self.ransackable_attributes(_auth_object = nil)
    %w[id email current_sign_in_at last_sign_in_at sign_in_count failed_attempts locked_at created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end
