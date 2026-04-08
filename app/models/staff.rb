class Staff < ApplicationRecord
  belongs_to :salon

  acts_as_tenant :salon

  devise :database_authenticatable, :recoverable, :rememberable, :validatable

  enum :role, { staff: 0, owner: 1 }

  has_many :expenses, dependent: :nullify
  has_many :visits, dependent: :nullify
  has_many :appointments, dependent: :nullify

  validates :name, presence: true
  validates :role, presence: true

  # Authorization — kept on the model, not in a policy object
  def can_manage_salon?
    owner?
  end

  def can_manage_staff?
    owner?
  end
end
