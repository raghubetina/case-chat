module ApplicationHelper
  def full_page_title
    [content_for(:title).presence, t("app_name")].compact.join(" · ")
  end

  # A few thousand tokens on a cheap model costs a fraction of a cent, and
  # rounding that to $0.00 tells an author the case was free. Anything that
  # rounds to nothing at two places says so instead.
  def money(amount, unknown: nil)
    return unknown if amount.nil?
    return number_to_currency(0) if amount.zero?

    (amount < 0.005) ? t("money.under_a_cent") : number_to_currency(amount, precision: 2)
  end

  # What a model costs, in words, for every catalogued model. Rendered once and
  # handed to the browser as a map so changing the model updates the line
  # without a request -- and so currency and translation stay on this side,
  # rather than being reimplemented in JavaScript.
  def model_price_summaries
    ModelCatalogue.ids.index_with { |id| model_price_summary(id) }
  end

  def model_price_summary(id)
    prices = ModelCatalogue.prices_for(id)
    return t("author.contacts.model_price_unknown") if prices.nil?

    # Most input on a repeat question is a cache read here -- the briefing is
    # cached deliberately -- so the headline input rate overstates what a busy
    # stakeholder actually bills. Named when the provider publishes it.
    if prices[:cached]
      return t("author.contacts.model_price_cached",
        input: money(prices[:input]), cached: money(prices[:cached]),
        output: money(prices[:output]))
    end

    t("author.contacts.model_price",
      input: money(prices[:input]), output: money(prices[:output]))
  end

  def rodauth_field_error_id(param_name)
    "#{param_name.to_s.tr("_", "-")}-error"
  end

  def rodauth_field_attributes(rodauth, param_name, describedby: nil)
    error_id = rodauth_field_error_id(param_name) if rodauth.field_error(param_name)
    description_ids = [describedby, error_id].compact.join(" ")
    return {} if description_ids.blank?

    aria = {describedby: description_ids}
    if error_id
      aria[:errormessage] = error_id
      aria[:invalid] = "true"
    end
    {aria: aria}
  end

  def rodauth_input_class(rodauth, param_name)
    class_names("input input-bordered w-full", "input-error": rodauth.field_error(param_name))
  end
end
