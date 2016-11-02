require "rails_helper"

RSpec.feature "Create enquiry", type: :feature do
  let!(:user) { create(:user, confirmed: true) }
  let!(:admin) { create(:user, user_type: "admin", confirmed: true) }
  let!(:enquiry) { create(:enquiry) }
  let!(:notification) do
    create(:notification,
           notifiable: enquiry,
           receiver_id: admin.id,
           sender_id: user.id)
  end

  context "when current_user is admin" do
    scenario "admin receives the enquiry" do
      log_in_with admin.email, admin.password
      visit notifications_path
      page.execute_script("$('#notification-btn').click()")

      expect(page).to have_content enquiry.question
    end
  end

  context "when current_user is sender of enquiry" do
    scenario "user gets response to question asked" do
      get_notification.reply_to_sender(Faker::Lorem.word, Faker::Lorem.word)
      log_in_with(user.email, user.password)
      visit notifications_path
      page.execute_script("$('#notification-btn').click()")

      expect(page).to have_content enquiry.response
    end
  end

  def get_notification
    Notification.find_by(notifiable_id: enquiry.id)
  end
end