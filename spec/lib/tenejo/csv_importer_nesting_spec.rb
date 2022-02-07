# frozen_string_literal: true
require 'csv'
require 'rails_helper'
require 'active_fedora/cleaner'

RSpec.describe Tenejo::CsvImporter do
  # rubocop:disable RSpec/InstanceVariable
  before :all do
    ActiveRecord::Base.connection.begin_transaction
    ActiveFedora::Cleaner.clean!
    described_class.reset_default_collection_type!
    job_owner = User.find_by(email: 'admin@example.org') || User.create(email: 'admin@example.org', password: 'abcd5678')
    csv = fixture_file_upload("./spec/fixtures/csv/structure_test.csv")
    preflight = Preflight.create!(user: job_owner, manifest: csv)
    import_job = Import.create!(user: job_owner, parent_job: preflight)
    @csv_import = described_class.new(import_job, './spec/fixtures/images/structure_test')
    @csv_import.import
  end

  after :all do
    conn = ActiveRecord::Base.connection
    conn.rollback_transaction if conn.transaction_open?
  end

  it 'runs without errors', :aggregate_failures do
    expect(@csv_import.preflight_errors).to be_empty
    expect(@csv_import.invalid_rows).to be_empty
    expect(@csv_import.preflight_warnings).to eq ["The column \"Comment\" is unknown, and will be ignored"]
  end

  it 'builds relationships', :aggregate_failures do
    parent = Collection.where(primary_identifier_ssi: 'EPHEM').first
    child = Collection.where(primary_identifier_ssi: 'CARDS').first
    grandchild = Work.where(primary_identifier_ssi: 'CARDS-0001').first
    greatgrandchild = Work.where(primary_identifier_ssi: 'CARDS-0001-J').first

    expect(parent.child_collections).to include child
    expect(child.parent_collections).to include parent
    expect(child.child_collections).to be_empty
    expect(child.child_works).to include grandchild
    expect(greatgrandchild.parent_works).to include grandchild
  end

  it 'sets work-level visibility', :aggregate_failures do
    private_work = Work.where(primary_identifier_ssi: 'ORPH-0001').first
    institutional_work = Work.where(primary_identifier_ssi: 'ORPH-0002').first
    public_work = Work.where(primary_identifier_ssi: 'CARDS-0001-J').first

    expect(private_work.visibility).to eq Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
    expect(institutional_work.visibility).to eq Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_AUTHENTICATED
    expect(public_work.visibility).to eq Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC
  end

  it 'sets collection-level visibility', :aggregate_failures do
    private_collection = Collection.where(primary_identifier_ssi: 'DARK').first
    public_collection = Collection.where(primary_identifier_ssi: 'CARDS').first

    expect(private_collection.visibility).to eq Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
    expect(public_collection.visibility).to eq Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC
  end
  # rubocop:enable RSpec/InstanceVariable
end
