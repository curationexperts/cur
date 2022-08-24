# frozen_string_literal: true
require 'rails_helper'

# This spec was generated by rspec-rails when you ran the scaffold generator.
# It demonstrates how one might use RSpec to test the controller code that
# was generated by Rails when you ran the scaffold generator.
#
# It assumes that the implementation code is generated by the rails scaffold
# generator. If you are using any extension libraries to generate different
# controller code, this generated spec may or may not pass.
#
# It only uses APIs available in rails and/or rspec-rails. There are a number
# of tools you can use to make these specs even more expressive, but we're
# sticking to rails and rspec-rails APIs to keep things simple and stable.

RSpec.describe "/jobs", type: :request do
  # Job. As you add validations to Job, be sure to
  # adjust the attributes here as well.
  let(:valid_attributes) {
    { type: nil,
      user: admin,
      label: "Label",
      status: "Status",
      collections: 2,
      works: 3,
      files: 4 }
  }

  let(:admin) { User.create(email: 'test@example.com', password: '123456', roles: [Role.create(name: 'admin')]) }

  before do
    sign_in admin
  end

  describe "GET /index" do
    it "renders a successful response" do
      Job.create! valid_attributes
      get jobs_url
      expect(response).to be_successful
    end

    it 'displays with the dashboard sidebar & layout' do
      get jobs_url
      expect(response).to be_successful
      expect(response).to render_template('layouts/hyrax/dashboard')
    end
  end

  describe "GET /show" do
    it "renders a successful response" do
      job = Job.create! valid_attributes
      get job_url(job)
      expect(response).to be_successful
    end
  end

  describe "GET /new" do
    it "renders a successful response" do
      get new_job_url
      expect(response).to be_successful
    end
  end
end
