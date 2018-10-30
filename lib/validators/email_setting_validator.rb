class EmailSettingValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    !val.present? || !!(::DiscourseEmailValidator.email_regex =~ val)
  end

  def error_message
    I18n.t('site_settings.errors.invalid_email')
  end
end
