require "rails_helper"

RSpec.describe Admin::ApplicantsController, type: :controller do
  before(:each) do
    @admin = create(:user, user_type: "admin")
    taskee_stub
    @applicants = Admin.get_applicants
    @applicant = @applicants[0]
  end
  describe "GET#index" do
    before(:each) { get :index }
    context "when user is logged in" do
      before(:each) do
        stub_current_user(@admin)
      end
      it "returns 200 status" do
        expect(response.status).to eq 200
      end

      it "renders index template" do
        expect(response).to render_template "index"
      end

      it "fetches applicants who have not been reviewed" do
        expect(assigns(:applicants)).to eq(@applicants)
      end
    end

    context "when user is not logged in" do
      it "returns 302 status response" do
        expect(response.status).to eq 302
      end

      it "redirects to root path" do
        expect(response).to redirect_to root_path
      end
    end
  end

  describe "GET#edit" do
    before(:each) do
      stub_current_user(@admin)
      taskee_stub
      get :edit, params: { id: @applicant.id }
    end

    it "returns 200 status response" do
      expect(response.status).to eq 200
    end

    it "renders edit template" do
      expect(response).to render_template :edit
    end
  end

  describe "PUT#update" do
    let(:user_attributes) {
      attributes_for(:user, id: user.id, status: "accepted")
    }
    before(:each) { put :update, id: user.id, user: user_attributes }

    it "redirects to the applicants page" do
      expect(response).to redirect_to admin_applicants_path
    end

    it "returns 302 status response" do
      expect(response.status).to eq 302
    end

    context "when status is accepted" do
      it "updates status to accepted" do
        expect(user.status).to_not eq user_attributes[:status]
      end
    end

    context "when status is rejected" do
      it "updates status to rejected" do
        expect(user.status).to_not eq user_attributes[:status]
      end
    end
  end
end
