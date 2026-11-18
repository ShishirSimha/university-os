module InstitutionResolution
  extend ActiveSupport::Concern

  private

  def institution_code
    raw = params[:institutionCode].presence || params[:institution_code].presence
    raw.to_s.strip.upcase.presence
  end

  def find_institution
    Tenant.find_by(code: institution_code) if institution_code.present?
  end

  def require_active_institution
    if institution_code.blank?
      render_error("Institution code can't be blank")
      return
    end

    tenant = find_institution
    if tenant.nil?
      render_error("Institution not found")
      return
    end

    if tenant.suspended?
      render_error("Institution is suspended")
      return
    end

    tenant
  end
end
