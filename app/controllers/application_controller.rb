# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  helper :all # include all helpers, all the time
  include SharedHelper
  include PreferencesHelper
  include ExceptionNotifiable

  helper_method :current_person
  helper_method :logged_in?

  filter_parameter_logging :password

  before_filter :create_page_view, :require_activation,
                :admin_warning,
                :set_person_locale

  ActiveScaffold.set_defaults do |config|
    config.ignore_columns.add [ :created_at, :updated_at ]
  end

  audit Req, Offer, Bid, Exchange, Account, Person, :only => [:create, :update, :destroy]

  # See ActionController::RequestForgeryProtection for details
  # Uncomment the :secret if you're not using the cookie session store
  protect_from_forgery # :secret => '71a8c82e6d248750397d166001c5e308'

  protected
    def logged_in?
      !!current_person
    end

    def authorized?
      logged_in?
    end

    def login_required
      unless current_person
        store_location
        flash[:notice] = "You must be logged in to view the page"
        redirect_to login_url
        return false
      end
    end

    def store_location
      session[:return_to] = request.request_uri
    end

    def redirect_back_or_default(default)
      redirect_to(session[:return_to] || default)
      session[:return_to] = nil
    end

    def current_person_session
      return @current_person_session if defined?(@current_person_session)
      @current_person_session = PersonSession.find
    end

    def current_person
      # login_or_oauth_required sets @current_person to nil
      return @current_person if defined?(@current_person) && @current_person
      @current_person = current_person_session && current_person_session.record
    end

    def current_user
      current_person 
    end

    def set_person_locale
      if logged_in?
        I18n.locale = current_person.language
      else
        session[:locale] = params[:locale] if params[:locale]
        I18n.locale = session[:locale] || I18n.default_locale
      end
    end

    def authorized?
      logged_in? and ( current_person.active? or current_person.admin? )
    end
  private

    def admin_required
      unless current_person.admin?
        flash[:error] = t("error_admin_access_required")
        redirect_to home_url
      end
    end
  
    # Create a Scribd-style PageView.
    # See http://www.scribd.com/doc/49575/Scaling-Rails-Presentation
    def create_page_view
      if request.format.html?
        #PageView.create(:person_id => session[:person_id],
        #                :request_url => request.request_uri,
        #                :ip_address => request.remote_ip,
        #                :referer => request.env["HTTP_REFERER"],
        #                :user_agent => request.env["HTTP_USER_AGENT"])
        if logged_in?
          # last_logged_in_at actually captures site activity, so update it now.
          current_person.last_logged_in_at = Time.now
          current_person.save
        end
      end
    end
  
    def require_activation
      if logged_in?
        unless current_person.active? or current_person.admin?
          redirect_to logout_url
        end
      end
    end
    
    # Warn the admin if his email address or password is still the default.
    def admin_warning
      if request.format.html?
        default_domain = "example.com"
        default_password = "admin"
        if logged_in? and current_person.admin? 
          if current_person.email =~ /@#{default_domain}$/
            flash[:notice] = %(#{t('notice_warning_your_email_address')} 
              #{default_domain}.
              <a href="#{edit_person_path(current_person)}">#{t('notice_change_it_here')}</a>.)
          end
          #if current_person.unencrypted_password == default_password
          #  flash[:error] = %(#{t('error_default_password')}
          #    <a href="#{edit_person_path(current_person)}">#{t('notice_change_it_here')}</a>.)          
          #end
        end
      end
    end
end