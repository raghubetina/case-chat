module ApplicationHelper
  def full_page_title
    [content_for(:title).presence, t("app_name")].compact.join(" · ")
  end
end
