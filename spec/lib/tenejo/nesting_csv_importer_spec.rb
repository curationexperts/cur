# frozen_string_literal: true
require 'csv'
require 'rails_helper'
require 'active_fedora/cleaner'

RSpec.describe Tenejo::CsvImporter do
  before :all do
    ActiveRecord::Base.connection.begin_transaction
    ActiveFedora::Cleaner.clean!
    described_class.reset_default_collection_type!
    job_owner = User.find_by(email: 'admin@example.org') || User.create(email: 'admin@example.org', password: 'abcd5678')
    csv = fixture_file_upload("./spec/fixtures/csv/structure_test.csv")
    preflight = Preflight.create!(user: job_owner, manifest: csv)
    import_job = Import.create!(user: job_owner, parent_job: preflight)
    csv_import = described_class.new(import_job)
    csv_import.import

    # this nonsense is to create relevant files so that the preflighter will not reject the records
    r = CSV.read('spec/fixtures/csv/structure_test.csv')
    FileUtils.mkdir_p('tmp/test/uploads')
    r.map { |z| z[8] }.reject(&:nil?).map { |t| t.split('|~|') }.flatten.reject { |k| k == 'Files' }.each do |f|
      FileUtils.touch("tmp/test/uploads/#{f}")
    end
  end

  after :all do
    conn = ActiveRecord::Base.connection
    conn.rollback_transaction if conn.transaction_open?
  end

  it 'builds relationships between parents and children', :aggregate_failures do
    parent = Collection.where(primary_identifier: 'EPHEM').first
    child = Collection.where(primary_identifier: 'CARDS').first
    grandchild = Work.where(primary_identifier: 'CARDS-0001').find { |w| w.identifier == ['CARDS-0001'] }
    greatgrandchild = Work.where(primary_identifier: 'CARDS-0001-J').find { |w| w.identifier == ['CARDS-0001-J'] }

    expect(parent.child_collections).to include child
    expect(child.parent_collections).to include parent
    expect(child.child_collections).to be_empty
    expect(child.child_works).to include grandchild
    expect(greatgrandchild.parent_works).to include grandchild
  end

  it 'sets visibility on works', :aggregate_failures do
    private_work = Work.where(primary_identifier: 'ORPH-0001').find { |w| w.identifier == ['ORPH-0001'] }
    institutional_work = Work.where(primary_identifier: 'ORPH-0002').find { |w| w.identifier == ['ORPH-0002'] }
    public_work = Work.where(primary_identifier: 'CARDS-0001-J').find { |w| w.identifier == ['CARDS-0001-J'] }

    expect(private_work.visibility).to eq Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
    expect(institutional_work.visibility).to eq Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_AUTHENTICATED
    expect(public_work.visibility).to eq Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC
    expect(Work.where(primary_identifier: 'CARDS-0001').count).to be > 1, "remember to simplify these test when identifier is refactored"
  end

  it 'sets visibility on collections', :aggregate_failures do
    private_collection = Collection.where(primary_identifier: 'DARK').first
    public_collection = Collection.where(primary_identifier: 'CARDS').find { |w| w.identifier == ['CARDS'] }

    expect(private_collection.visibility).to eq Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
    expect(public_collection.visibility).to eq Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC
  end
end