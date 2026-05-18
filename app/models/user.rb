class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  pay_customer

  enum :plan, { free: 0, basic: 1, pro: 2 }, default: :free
end
