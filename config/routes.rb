Rails.application.routes.draw do
  # Public marketing / registration (no subdomain)
  constraints subdomain: "" do
    root "home#index", as: :marketing_root
    get  "register", to: "registrations#new",    as: :new_salon_registration
    post "register", to: "registrations#create",  as: :salon_registrations
  end

  # Tenant-scoped app (subdomain present)
  constraints subdomain: /\A[a-z0-9\-]+\z/ do
    devise_for :staffs, controllers: { sessions: "staffs/sessions" }

    root "salon_home#index"
    get "dashboard", to: "dashboard#index", as: :dashboard

    # QR scan — public, no auth required
    get "scan/:qr_token", to: "visits#scan", as: :scan_qr

    resources :customers do
      member do
        get  :qr_code
        post :share_loyalty_card
      end
    end

    # Public loyalty card — shareable link using qr_token, no auth required
    get "loyalty/:qr_token", to: "loyalty_cards#show", as: :loyalty_card

    resources :services

    resources :visits, only: %i[index new create show]

    resources :appointments do
      collection { get :slots }
      resource  :confirmation, only: %i[ create ], module: :appointments
      resource  :cancellation, only: %i[ create ], module: :appointments
      resource  :completion,   only: %i[ create ], module: :appointments
    end

    # Public customer self-booking (no auth)
    get  "book", to: "bookings#new",    as: :new_booking
    post "book", to: "bookings#create", as: :bookings
    get  "book/slots", to: "bookings#slots", as: :booking_slots

    resources :working_hours, only: %i[index edit update] do
      collection { patch :update }
    end
    resources :expenses
    get "reports",          to: "reports#index",    as: :reports
    get "reports/services", to: "reports#services", as: :service_reports
    get "reports/discounts", to: "reports#discounts", as: :discount_reports

    resources :staffs, except: %i[ show ]

    resource  :settings, only: %i[ edit update ]
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
