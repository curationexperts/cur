# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tenejo::CsvExporter do
  let(:job_owner) { FactoryBot.create(:user) }
  let(:export) { Export.new(user: job_owner, status: :submitted) }

  context '#run' do
    it 'attaches a CSV file to the job', :aggregate_failures do
      expect(export.manifest.attached?).to be false
      described_class.new(export).run
      expect(export.manifest.attached?).to be true
    end

    it 'sets the job status', :aggregate_failures do
      expect(export.status).to eq 'submitted'
      expect(export.completed_at).to be_nil
      described_class.new(export).run
      expect(export.status).to eq 'completed'
      expect(export.completed_at).to be_within(1.second).of Time.current
    end

    it 'calls #generate_csv' do
      exporter = described_class.new(export)
      allow(exporter).to receive(:generate_csv).and_return('')
      exporter.run
      expect(exporter).to have_received(:generate_csv).once
    end
  end

  context "#generate_csv" do
    let(:col001) {
      Collection.new(title: ['Test collection'], primary_identifier: 'COL001',
                     collection_type_gid: Hyrax::CollectionType.find_or_create_default_collection_type.gid)
    }

    let(:work001) { Work.new(title: ['Test work'], primary_identifier: 'WRK001') }

    let(:work002) { Work.new(title: ['Another Test work'], primary_identifier: 'WRK002') }

    it 'includes error message if no identifiers were provided' do
      csv_string = described_class.new(export).generate_csv
      rows = CSV.parse(csv_string, headers: true)
      expect(rows.first['error']).to eq 'No identifiers provided'
    end

    it 'includes row-level errors' do
      export.identifiers = ['invalid_id']
      csv_string = described_class.new(export).generate_csv
      rows = CSV.parse(csv_string, headers: true)
      expect(rows.first['identifier']).to eq 'invalid_id'
      expect(rows.first['error']).to eq 'No match for identifier'
    end

    it 'includes metadata for collections and works', :aggregate_failures do
      allow(ActiveFedora::Base).to receive(:where).and_return([col001], [work001])

      export.identifiers = ['COL001', 'WRK001']
      csv_string = described_class.new(export).generate_csv
      rows = CSV.parse(csv_string, headers: true)

      # Collection COL001
      expect(rows[0]['identifier']).to eq 'COL001'
      expect(rows[0]['error']).to be_nil
      expect(rows[0]['title']).to include 'Test collection'
      expect(rows[0]['object type']).to eq "Collection"

      # Work WRK001
      expect(rows[1]['identifier']).to eq 'WRK001'
      expect(rows[1]['error']).to be_nil
      expect(rows[1]['title']).to include 'Test work'
      expect(rows[1]['object type']).to eq "Work"
    end

    it 'includes children', :aggregate_failures do
      allow(ActiveFedora::Base).to receive(:where).and_return([col001], [work001], [work002])
      allow(col001).to receive(:child_works).and_return([work001])
      allow(work001).to receive(:child_works).and_return([work002])

      export.identifiers = ['COL001']
      csv_string = described_class.new(export).generate_csv
      rows = CSV.parse(csv_string, headers: true)

      expect(rows[0]['parent']).to be_blank
      expect(rows[0]['identifier']).to eq 'COL001'
      expect(rows[1]['parent']).to eq 'COL001'
      expect(rows[1]['identifier']).to eq 'WRK001'
      expect(rows[2]['parent']).to eq 'WRK001'
      expect(rows[2]['identifier']).to eq 'WRK002'
    end
  end

  context "#serialize" do
    let(:max_work) {
      Work.new(
        title: ['Work with all the fields'],
        primary_identifier: 'MAX-WORK',
        identifier: ['DOI:xxxxxxx', 'https://hdl.handle.net/ooooo/iiiiiiiii'],
        alternative_title: ['Alle Felder', 'सर्वाणि क्षेत्राणि'],
        resource_type: ["Image"],
        creator: ["Anon., 16th Century"],
        contributor: ["c2"],
        description: ["Here's some mixed \"s & quotes'"],
        abstract: ["impressionism"],
        keyword: ["none", "one", "some"],
        license: ["All rights reserved"],
        rights_notes: ["use freely"],
        rights_statement: ["No Copyright - United States"],
        publisher: ["DCE"],
        date_created: ["2021-12-06"],
        subject: ["tbd"],
        language: ["english"],
        related_url: ["/also/#"],
        bibliographic_citation: ["see also"],
        source: ["mhb"],
        # single valued
        depositor: "admin@example.com",
        date_uploaded: "2021-01-01 00:00:01",
        date_modified: nil
      )
    }

    let(:serialized) { described_class.new(export).send(:serialize, max_work, 'PARENT_ID') }

    it "returns a CSV::Row" do
      expect(serialized).to be_a CSV::Row
    end

    it "includes a parent id" do
      expect(serialized[:parent]).to eq 'PARENT_ID'
    end

    it "handles all the fields" do
      # Just check for one value deep in the array
      # Otherwise we need to check the whole exact string and the test becomes fragile
      expect(serialized[:rights_notes]).to include 'use freely'
    end

    it "handles multi-valued fields" do
      expect(serialized[:alternative_title].split('|~|')).to contain_exactly('Alle Felder', 'सर्वाणि क्षेत्राणि')
    end

    it "handles embedded quotes" do
      expect(serialized[:description]).to eq %q(Here's some mixed "s & quotes')
    end

    it "handles embedded commas" do
      expect(serialized[:creator]).to eq 'Anon., 16th Century'
    end
  end
end
