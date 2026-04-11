class Customer < ApplicationRecord
  belongs_to :salon
  has_many :visits, dependent: :destroy
  has_many :appointments, dependent: :destroy

  acts_as_tenant :salon

  before_create :generate_qr_token

  validates :name, presence: true
  validates :phone_number, presence: true,
                           uniqueness: { scope: :salon_id, message: "is already registered at this salon" }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  # -- Scopes ------------------------------------------------------------------

  scope :alphabetically,       -> { order(:name) }
  scope :recently_joined,      -> { order(created_at: :desc) }
  scope :by_phone,             ->(phone) { where("phone_number LIKE ?", "%#{phone}%") }
  scope :by_name,              ->(name)  { where("LOWER(name) LIKE ?", "%#{name.downcase}%") }
  scope :search,               ->(q)     { where("LOWER(name) LIKE :q OR phone_number LIKE :q", q: "%#{q.downcase}%") }
  # Customers exactly one visit away from their next free cut
  scope :near_loyalty_milestone, ->(threshold) {
    where("visits_count % ? = ?", threshold, threshold - 1).where("visits_count > 0")
  }

  # -- Loyalty -----------------------------------------------------------------

  def visits_until_free
    threshold = salon.loyalty_threshold
    threshold - (visits_count % threshold)
  end

  def next_visit_free?
    visits_until_free == 1
  end

  def loyalty_milestone?
    visits_count > 0 && (visits_count % salon.loyalty_threshold).zero?
  end

  # -- QR code -----------------------------------------------------------------

  def qr_code_svg(content = qr_token)
    qr = RQRCode::QRCode.new(content)
    qr.as_svg(offset: 0, color: "000", shape_rendering: "crispEdges", module_size: 4, standalone: true)
  end

  private
    def generate_qr_token
      self.qr_token = SecureRandom.urlsafe_base64(16)
    end
end
