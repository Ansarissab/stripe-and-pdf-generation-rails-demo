class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :trackable, :confirmable, :lockable

  pay_customer

  enum :plan, { basic: 0, pro: 1 }
end
