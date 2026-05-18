class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  pay_customer

  enum :plan, { basic: 0, pro: 1 }
end
