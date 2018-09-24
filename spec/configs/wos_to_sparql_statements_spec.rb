# frozen_string_literal: true

require 'rdf'
require 'traject'
require 'sparql'
require 'sparql/client'
require 'rialto/etl/readers/sparql_statement_reader'
require 'rialto/etl/namespaces'

RSpec.describe Rialto::Etl::Transformer do
  let(:config_file_path) { 'lib/rialto/etl/configs/wos_to_sparql_statements.rb' }

  describe 'wos_to_sparql_statements' do
    let(:repository) do
      RDF::Repository.new.tap do |repo|
        repo.insert(RDF::Statement.new(RDF::URI.new('foo'),
                                       RDF::URI.new('bar'),
                                       RDF::URI('foobar'),
                                       graph_name: Rialto::Etl::NamedGraphs::WOS_GRAPH))
      end
    end

    let(:client) do
      SPARQL::Client.new(repository)
    end

    def transform(source_file)
      statements_io = StringIO.new

      transformer = Traject::Indexer.new.tap do |indexer|
        indexer.load_config_file(config_file_path)
        indexer.settings['output_stream'] = statements_io
      end

      # Converting fixture from pretty-printed JSON to single line.
      transformer.process(StringIO.new(File.open(source_file) { |file| file.read.delete("\n") }))
      statement_reader = Rialto::Etl::Readers::SparqlStatementReader.new(StringIO.new(statements_io.string),
                                                                         'sparql_statement_reader.by_statement' => true)
      statement_reader.each do |statement|
        SPARQL.execute(statement, repository, update: true)
      end
    end

    describe 'insert' do
      before do
        stub_request(:get, 'http://127.0.0.1:3001/person?country=USA&first_name=Jennifer%20L.&full_name=Wilson,%20Jennifer%20L.&last_name=Wilson&orcid_id=0000-0002-2328-2018&organization=Stanford%20University')
          .with(headers: { 'X-Api-Key' => 'abc123' })
          .to_return(status: 200, body: 'http://sul.stanford.edu/rialto/agents/people/15bf29be-470a-442e-9389-f66aac440a7b')

        stub_request(:get, 'http://127.0.0.1:3001/person?country=USA&first_name=Russ%20B.&full_name=Altman,%20Russ%20B.&last_name=Altman&organization=Stanford%20University')
          .with(headers: { 'X-Api-Key' => 'abc123' })
          .to_return(status: 200, body: 'http://sul.stanford.edu/rialto/agents/people/dc934b74-e554-409b-967b-0d555c44cc2c')

        stub_request(:get, 'http://127.0.0.1:3001/topic?name=Research%20%26%20Experimental%20Medicine')
          .with(headers: { 'X-Api-Key' => 'abc123' })
          .to_return(status: 200, body: 'http://sul.stanford.edu/rialto/concepts/d700824f-ae47-4244-885c-7cfc55b240f9')

        transform('spec/fixtures/wos/000424386600014.json')
      end

      it 'is inserted with publication triples' do
        # 1 publication
        query = client.select(count: { doc: :c })
                      .from(Rialto::Etl::NamedGraphs::WOS_GRAPH)
                      .where([:doc, RDF.type, Rialto::Etl::Vocabs::BIBO['Document']])
        expect(query.solutions.first[:c].to_i).to eq(1)

        # has Part
        expect(repository).to have_quad([Rialto::Etl::Vocabs::RIALTO_PUBLICATIONS['1361324f8ff0b8ef1ed408a1f0b58107'],
                                         Rialto::Etl::Vocabs::DCTERMS['isPartOf'],
                                         'EXPERIMENTAL BIOLOGY AND MEDICINE',
                                         Rialto::Etl::NamedGraphs::WOS_GRAPH])

        # Created
        expect(repository).to have_quad([Rialto::Etl::Vocabs::RIALTO_PUBLICATIONS['1361324f8ff0b8ef1ed408a1f0b58107'],
                                         Rialto::Etl::Vocabs::DCTERMS['created'],
                                         '2018-02-01',
                                         Rialto::Etl::NamedGraphs::WOS_GRAPH])

        # Subject
        expect(repository).to have_quad([Rialto::Etl::Vocabs::RIALTO_PUBLICATIONS['1361324f8ff0b8ef1ed408a1f0b58107'],
                                         Rialto::Etl::Vocabs::DCTERMS['subject'],
                                         Rialto::Etl::Vocabs::RIALTO_CONCEPTS['d700824f-ae47-4244-885c-7cfc55b240f9'],
                                         Rialto::Etl::NamedGraphs::WOS_GRAPH])

        # Title
        expect(repository).to have_quad([Rialto::Etl::Vocabs::RIALTO_PUBLICATIONS['1361324f8ff0b8ef1ed408a1f0b58107'],
                                         Rialto::Etl::Vocabs::DCTERMS['title'],
                                         'Biomarkers: Delivering on the expectation of molecularly driven, quantitative health',
                                         Rialto::Etl::NamedGraphs::WOS_GRAPH])

        # Abstract
        expect(repository).to have_quad([Rialto::Etl::Vocabs::RIALTO_PUBLICATIONS['1361324f8ff0b8ef1ed408a1f0b58107'],
                                         Rialto::Etl::Vocabs::BIBO['abstract'],
                                         'Biomarkers are the pillars of precision medicine and are delivering on '\
                                         'expectations of molecular, quantitative health.',
                                         Rialto::Etl::NamedGraphs::WOS_GRAPH])
        # DOI
        expect(repository).to have_quad([Rialto::Etl::Vocabs::RIALTO_PUBLICATIONS['1361324f8ff0b8ef1ed408a1f0b58107'],
                                         Rialto::Etl::Vocabs::BIBO['doi'],
                                         '10.1177/1535370217744775',
                                         Rialto::Etl::NamedGraphs::WOS_GRAPH])
        # Identifier
        expect(repository).to has_quads([[Rialto::Etl::Vocabs::RIALTO_PUBLICATIONS['1361324f8ff0b8ef1ed408a1f0b58107'],
                                          Rialto::Etl::Vocabs::BIBO['identifier'],
                                          '1535-3702',
                                          Rialto::Etl::NamedGraphs::WOS_GRAPH],
                                         [Rialto::Etl::Vocabs::RIALTO_PUBLICATIONS['1361324f8ff0b8ef1ed408a1f0b58107'],
                                          Rialto::Etl::Vocabs::BIBO['identifier'],
                                          '1535-3699',
                                          Rialto::Etl::NamedGraphs::WOS_GRAPH],
                                         [Rialto::Etl::Vocabs::RIALTO_PUBLICATIONS['1361324f8ff0b8ef1ed408a1f0b58107'],
                                          Rialto::Etl::Vocabs::BIBO['identifier'],
                                          '10.1177/1535370217744775',
                                          Rialto::Etl::NamedGraphs::WOS_GRAPH],
                                         [Rialto::Etl::Vocabs::RIALTO_PUBLICATIONS['1361324f8ff0b8ef1ed408a1f0b58107'],
                                          Rialto::Etl::Vocabs::BIBO['identifier'],
                                          'MEDLINE:29199461',
                                          Rialto::Etl::NamedGraphs::WOS_GRAPH]])

        # Publisher
        expect(repository).to have_quad([Rialto::Etl::Vocabs::RIALTO_PUBLICATIONS['1361324f8ff0b8ef1ed408a1f0b58107'],
                                         Rialto::Etl::Vocabs::VIVO['publisher'],
                                         'SAGE PUBLICATIONS LTD',
                                         Rialto::Etl::NamedGraphs::WOS_GRAPH])

        # Authorships
        expect(repository).to has_quads(
          [[Rialto::Etl::Vocabs::RIALTO_PUBLICATIONS['1361324f8ff0b8ef1ed408a1f0b58107'],
            Rialto::Etl::Vocabs::VIVO['relatedBy'],
            Rialto::Etl::Vocabs::RIALTO_CONTEXT_RELATIONSHIPS['WOS:000424386600014_15bf29be-470a-442e-9389-f66aac440a7b'],
            Rialto::Etl::NamedGraphs::WOS_GRAPH],
           [Rialto::Etl::Vocabs::RIALTO_CONTEXT_RELATIONSHIPS['WOS:000424386600014_15bf29be-470a-442e-9389-f66aac440a7b'],
            RDF.type,
            Rialto::Etl::Vocabs::VIVO['Authorship'],
            Rialto::Etl::NamedGraphs::WOS_GRAPH],
           [Rialto::Etl::Vocabs::RIALTO_CONTEXT_RELATIONSHIPS['WOS:000424386600014_15bf29be-470a-442e-9389-f66aac440a7b'],
            Rialto::Etl::Vocabs::VIVO['relates'],
            Rialto::Etl::Vocabs::RIALTO_PEOPLE['15bf29be-470a-442e-9389-f66aac440a7b'],
            Rialto::Etl::NamedGraphs::WOS_GRAPH],
           [Rialto::Etl::Vocabs::RIALTO_CONTEXT_RELATIONSHIPS['WOS:000424386600014_dc934b74-e554-409b-967b-0d555c44cc2c'],
            Rialto::Etl::Vocabs::VIVO['relates'],
            Rialto::Etl::Vocabs::RIALTO_PEOPLE['dc934b74-e554-409b-967b-0d555c44cc2c'],
            Rialto::Etl::NamedGraphs::WOS_GRAPH]]
        )
      end
    end
    describe 'create subjects and people' do
      before do
        stub_request(:get, 'http://127.0.0.1:3001/person?country=USA&first_name=Jennifer%20L.&full_name=Wilson,%20Jennifer%20L.&last_name=Wilson&orcid_id=0000-0002-2328-2018&organization=Stanford%20University')
          .with(headers: { 'X-Api-Key' => 'abc123' })
          .to_return(status: 404)

        stub_request(:get, 'http://127.0.0.1:3001/person?country=USA&first_name=Russ%20B.&full_name=Altman,%20Russ%20B.&last_name=Altman&organization=Stanford%20University')
          .with(headers: { 'X-Api-Key' => 'abc123' })
          .to_return(status: 404)

        stub_request(:get, 'http://127.0.0.1:3001/topic?name=Research%20%26%20Experimental%20Medicine')
          .with(headers: { 'X-Api-Key' => 'abc123' })
          .to_return(status: 404)

        transform('spec/fixtures/wos/000424386600014.json')
      end

      it 'is inserted with subject triples' do
        expect(repository).to have_quad([Rialto::Etl::Vocabs::RIALTO_PUBLICATIONS['1361324f8ff0b8ef1ed408a1f0b58107'],
                                         Rialto::Etl::Vocabs::DCTERMS['subject'],
                                         Rialto::Etl::Vocabs::RIALTO_CONCEPTS['5a2cd5c7582ed1a1bbcc3a5c62786dca'],
                                         Rialto::Etl::NamedGraphs::WOS_GRAPH])

        expect(repository).to have_quad([Rialto::Etl::Vocabs::RIALTO_CONCEPTS['5a2cd5c7582ed1a1bbcc3a5c62786dca'],
                                         RDF.type,
                                         Rialto::Etl::Vocabs::SKOS['Concept'],
                                         Rialto::Etl::NamedGraphs::WOS_GRAPH])

        expect(repository).to have_quad([Rialto::Etl::Vocabs::RIALTO_CONCEPTS['5a2cd5c7582ed1a1bbcc3a5c62786dca'],
                                         Rialto::Etl::Vocabs::DCTERMS['subject'],
                                         'Research & Experimental Medicine',
                                         Rialto::Etl::NamedGraphs::WOS_GRAPH])
      end

      it 'is inserted with people triples' do
        expect(repository).to has_quads([[Rialto::Etl::Vocabs::RIALTO_PEOPLE['5054d6965532201e275067e4766c0ea0'],
                                          RDF.type,
                                          Rialto::Etl::Vocabs::FOAF['Person'],
                                          Rialto::Etl::NamedGraphs::WOS_GRAPH],
                                         [Rialto::Etl::Vocabs::RIALTO_PEOPLE['5054d6965532201e275067e4766c0ea0'],
                                          RDF.type,
                                          Rialto::Etl::Vocabs::FOAF['Agent'],
                                          Rialto::Etl::NamedGraphs::WOS_GRAPH]])
      end
    end

    describe 'update publication' do
      before do
        stub_request(:get, 'http://127.0.0.1:3001/person?country=USA&first_name=Jennifer%20L.&full_name=Wilson,%20Jennifer%20L.&last_name=Wilson&orcid_id=0000-0002-2328-2018&organization=Stanford%20University')
          .with(headers: { 'X-Api-Key' => 'abc123' })
          .to_return(status: 200, body: 'http://sul.stanford.edu/rialto/agents/people/15bf29be-470a-442e-9389-f66aac440a7b')

        stub_request(:get, 'http://127.0.0.1:3001/person?country=USA&first_name=Russ%20B.&full_name=Altman,%20Russ%20B.&last_name=Altman&organization=Stanford%20University')
          .with(headers: { 'X-Api-Key' => 'abc123' })
          .to_return(status: 200, body: 'http://sul.stanford.edu/rialto/agents/people/dc934b74-e554-409b-967b-0d555c44cc2c')

        stub_request(:get, 'http://127.0.0.1:3001/person?country=USA&first_name=Justin%20C.&full_name=Littman,%20Justin%20C.&last_name=Littman&organization=Stanford%20University')
          .with(headers: { 'X-Api-Key' => 'abc123' })
          .to_return(status: 200, body: 'http://sul.stanford.edu/rialto/agents/people/dc934b74-e554-409b-967b-0d555c44cc2d')

        stub_request(:get, 'http://127.0.0.1:3001/topic?name=Research%20%26%20Experimental%20Medicine')
          .with(headers: { 'X-Api-Key' => 'abc123' })
          .to_return(status: 200, body: 'http://sul.stanford.edu/rialto/concepts/d700824f-ae47-4244-885c-7cfc55b240f9')

        stub_request(:get, 'http://127.0.0.1:3001/topic?name=Research%20%26%20Speculative%20Medicine')
          .with(headers: { 'X-Api-Key' => 'abc123' })
          .to_return(status: 200, body: 'http://sul.stanford.edu/rialto/concepts/d700824f-ae47-4244-885c-7cfc55b240f10')

        transform('spec/fixtures/wos/000424386600014.json')
        transform('spec/fixtures/wos/000424386600014-2.json')
      end

      it 'updates the publication' do
        # has Part
        expect(repository).to have_quad([Rialto::Etl::Vocabs::RIALTO_PUBLICATIONS['1361324f8ff0b8ef1ed408a1f0b58107'],
                                         Rialto::Etl::Vocabs::DCTERMS['isPartOf'],
                                         'SPECULATIVE BIOLOGY AND MEDICINE',
                                         Rialto::Etl::NamedGraphs::WOS_GRAPH])
        expect(repository).not_to have_quad([Rialto::Etl::Vocabs::RIALTO_PUBLICATIONS['1361324f8ff0b8ef1ed408a1f0b58107'],
                                             Rialto::Etl::Vocabs::DCTERMS['isPartOf'],
                                             'EXPERIMENTAL BIOLOGY AND MEDICINE',
                                             Rialto::Etl::NamedGraphs::WOS_GRAPH])

        # Created
        expect(repository).to have_quad([Rialto::Etl::Vocabs::RIALTO_PUBLICATIONS['1361324f8ff0b8ef1ed408a1f0b58107'],
                                         Rialto::Etl::Vocabs::DCTERMS['created'],
                                         '2017-02-01',
                                         Rialto::Etl::NamedGraphs::WOS_GRAPH])
        expect(repository).not_to have_quad([Rialto::Etl::Vocabs::RIALTO_PUBLICATIONS['1361324f8ff0b8ef1ed408a1f0b58107'],
                                             Rialto::Etl::Vocabs::DCTERMS['created'],
                                             '2018-02-01',
                                             Rialto::Etl::NamedGraphs::WOS_GRAPH])

        # Subject
        expect(repository).to have_quad([Rialto::Etl::Vocabs::RIALTO_PUBLICATIONS['1361324f8ff0b8ef1ed408a1f0b58107'],
                                         Rialto::Etl::Vocabs::DCTERMS['subject'],
                                         Rialto::Etl::Vocabs::RIALTO_CONCEPTS['d700824f-ae47-4244-885c-7cfc55b240f10'],
                                         Rialto::Etl::NamedGraphs::WOS_GRAPH])
        expect(repository).not_to have_quad([Rialto::Etl::Vocabs::RIALTO_PUBLICATIONS['1361324f8ff0b8ef1ed408a1f0b58107'],
                                             Rialto::Etl::Vocabs::DCTERMS['subject'],
                                             Rialto::Etl::Vocabs::RIALTO_CONCEPTS['d700824f-ae47-4244-885c-7cfc55b240f9'],
                                             Rialto::Etl::NamedGraphs::WOS_GRAPH])

        # Title
        expect(repository).to have_quad([Rialto::Etl::Vocabs::RIALTO_PUBLICATIONS['1361324f8ff0b8ef1ed408a1f0b58107'],
                                         Rialto::Etl::Vocabs::DCTERMS['title'],
                                         'Biomarkers: Delivering some day on the expectation of molecularly driven, '\
                                         'quantitative health',
                                         Rialto::Etl::NamedGraphs::WOS_GRAPH])
        expect(repository).not_to have_quad([Rialto::Etl::Vocabs::RIALTO_PUBLICATIONS['1361324f8ff0b8ef1ed408a1f0b58107'],
                                             Rialto::Etl::Vocabs::DCTERMS['title'],
                                             'Biomarkers: Delivering on the expectation of molecularly driven, quantitative health',
                                             Rialto::Etl::NamedGraphs::WOS_GRAPH])

        # Abstract
        expect(repository).to have_quad([Rialto::Etl::Vocabs::RIALTO_PUBLICATIONS['1361324f8ff0b8ef1ed408a1f0b58107'],
                                         Rialto::Etl::Vocabs::BIBO['abstract'],
                                         'Biomarkers are the pillars of precision medicine and may some day deliver on '\
                                         'expectations of molecular, quantitative health.',
                                         Rialto::Etl::NamedGraphs::WOS_GRAPH])
        expect(repository).not_to have_quad([Rialto::Etl::Vocabs::RIALTO_PUBLICATIONS['1361324f8ff0b8ef1ed408a1f0b58107'],
                                             Rialto::Etl::Vocabs::BIBO['abstract'],
                                             'Biomarkers are the pillars of precision medicine and are delivering on '\
                                             'expectations of molecular, quantitative health.',
                                             Rialto::Etl::NamedGraphs::WOS_GRAPH])
        # DOI
        expect(repository).to have_quad([Rialto::Etl::Vocabs::RIALTO_PUBLICATIONS['1361324f8ff0b8ef1ed408a1f0b58107'],
                                         Rialto::Etl::Vocabs::BIBO['doi'],
                                         '10.1177/1535370217744774',
                                         Rialto::Etl::NamedGraphs::WOS_GRAPH])
        expect(repository).not_to have_quad([Rialto::Etl::Vocabs::RIALTO_PUBLICATIONS['1361324f8ff0b8ef1ed408a1f0b58107'],
                                             Rialto::Etl::Vocabs::BIBO['doi'],
                                             '10.1177/1535370217744775',
                                             Rialto::Etl::NamedGraphs::WOS_GRAPH])
        # Identifier
        expect(repository).to has_quads([[Rialto::Etl::Vocabs::RIALTO_PUBLICATIONS['1361324f8ff0b8ef1ed408a1f0b58107'],
                                          Rialto::Etl::Vocabs::BIBO['identifier'],
                                          '1535-3670',
                                          Rialto::Etl::NamedGraphs::WOS_GRAPH],
                                         [Rialto::Etl::Vocabs::RIALTO_PUBLICATIONS['1361324f8ff0b8ef1ed408a1f0b58107'],
                                          Rialto::Etl::Vocabs::BIBO['identifier'],
                                          '10.1177/1535370217744774',
                                          Rialto::Etl::NamedGraphs::WOS_GRAPH],
                                         [Rialto::Etl::Vocabs::RIALTO_PUBLICATIONS['1361324f8ff0b8ef1ed408a1f0b58107'],
                                          Rialto::Etl::Vocabs::BIBO['identifier'],
                                          'MEDLINE:29199461',
                                          Rialto::Etl::NamedGraphs::WOS_GRAPH]])
        expect(repository).not_to has_quads([[Rialto::Etl::Vocabs::RIALTO_PUBLICATIONS['1361324f8ff0b8ef1ed408a1f0b58107'],
                                              Rialto::Etl::Vocabs::BIBO['identifier'],
                                              '1535-3702',
                                              Rialto::Etl::NamedGraphs::WOS_GRAPH],
                                             [Rialto::Etl::Vocabs::RIALTO_PUBLICATIONS['1361324f8ff0b8ef1ed408a1f0b58107'],
                                              Rialto::Etl::Vocabs::BIBO['identifier'],
                                              '1535-3699']])

        # Publisher
        expect(repository).to have_quad([Rialto::Etl::Vocabs::RIALTO_PUBLICATIONS['1361324f8ff0b8ef1ed408a1f0b58107'],
                                         Rialto::Etl::Vocabs::VIVO['publisher'],
                                         'MONOPOLY PUBLICATIONS LTD',
                                         Rialto::Etl::NamedGraphs::WOS_GRAPH])
        expect(repository).not_to have_quad([Rialto::Etl::Vocabs::RIALTO_PUBLICATIONS['1361324f8ff0b8ef1ed408a1f0b58107'],
                                             Rialto::Etl::Vocabs::VIVO['publisher'],
                                             'SAGE PUBLICATIONS LTD',
                                             Rialto::Etl::NamedGraphs::WOS_GRAPH])

        # Authorships
        expect(repository).to has_quads(
          [[Rialto::Etl::Vocabs::RIALTO_CONTEXT_RELATIONSHIPS['WOS:000424386600014_15bf29be-470a-442e-9389-f66aac440a7b'],
            Rialto::Etl::Vocabs::VIVO['relates'],
            Rialto::Etl::Vocabs::RIALTO_PEOPLE['15bf29be-470a-442e-9389-f66aac440a7b'],
            Rialto::Etl::NamedGraphs::WOS_GRAPH],
           [Rialto::Etl::Vocabs::RIALTO_CONTEXT_RELATIONSHIPS['WOS:000424386600014_dc934b74-e554-409b-967b-0d555c44cc2d'],
            Rialto::Etl::Vocabs::VIVO['relates'],
            Rialto::Etl::Vocabs::RIALTO_PEOPLE['dc934b74-e554-409b-967b-0d555c44cc2d'],
            Rialto::Etl::NamedGraphs::WOS_GRAPH]]
        )
        # Don't get rid of Authorship; just get rid of relationship between authorship and publication
        expect(repository).not_to have_quad([Rialto::Etl::Vocabs::RIALTO_PUBLICATIONS['1361324f8ff0b8ef1ed408a1f0b58107'],
                                             Rialto::Etl::Vocabs::VIVO['relatedBy'],
                                             Rialto::Etl::Vocabs::RIALTO_CONTEXT_RELATIONSHIPS['WOS:000424386600014_'\
                                               'dc934b74-e554-409b-967b-0d555c44cc2c'],
                                             Rialto::Etl::NamedGraphs::WOS_GRAPH])
      end
    end
  end
  describe '#fetch_addresses' do
    subject { indexer.fetch_addresses(json) }

    let(:indexer) do
      Traject::Indexer.new.tap do |indexer|
        indexer.load_config_file(config_file_path)
      end
    end

    context 'with an address that does not have a pref label' do
      let(:json) do
        <<~JSON
          {
          	"UID": "WOS:000359895400001",
          	"static_data": {
          		"fullrecord_metadata": {
          			"addresses": {
          				"address_name": [{
          					"address_spec": {
          						"country": "USA",
          						"city": "Palo Alto",
          						"addr_no": 2,
          						"organizations": {
          							"organization": "Vet Adm Palo Alto",
          							"count": 1
          						},
          						"full_address": "Vet Adm Palo Alto, Palo Alto, CA USA",
          						"state": "CA"
          					}
          				}]
          			}
          		}
          	}
          }
        JSON
      end

      it { is_expected.to eq(2 => { 'country' => 'USA', 'organization' => 'Vet Adm Palo Alto' }) }
    end
    context 'with an address with a pref label' do
      let(:json) do
        <<~JSON2
          {
            "UID": "WOS:000359895400001",
            "static_data": {
              "fullrecord_metadata": {
                "addresses": {
                  "address_name": [{
                    "address_spec": {
                      "zip": {
          							"location": "AP",
          							"content": 94305
          						},
          						"country": "USA",
          						"city": "Stanford",
          						"addr_no": 1,
          						"organizations": {
          							"organization": ["Stanford Univ", {
          								"pref": "Y",
          								"content": "Stanford University"
          							}],
          							"count": 2
          						},
          						"full_address": "Stanford Univ, Stanford Cardiovasc Inst, Sch Med, Stanford, CA 94305 USA",
          						"state": "CA",
          						"suborganizations": {
          							"count": 2,
          							"suborganization": ["Stanford Cardiovasc Inst", "Sch Med"]
          						}
                    }
                  }]
                }
              }
            }
          }
        JSON2
      end

      it { is_expected.to eq(1 => { 'country' => 'USA', 'organization' => 'Stanford University' }) }
    end
  end
end