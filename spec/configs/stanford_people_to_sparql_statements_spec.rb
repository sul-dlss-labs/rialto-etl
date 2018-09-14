# frozen_string_literal: true

require 'rdf'
require 'traject'
require 'sparql'
require 'sparql/client'
require 'rialto/etl/readers/sparql_statement_reader'
require 'rialto/etl/namespaces'

STANFORD_PERSON_INSERT = <<~JSON
  {
    "profileId": 400150,
    "affiliations": {
      "capFaculty": true,
      "capStaff": false,
      "capPostdoc": false,
      "capMdStudent": false,
      "capMsStudent": false,
      "capPhdStudent": false,
      "physician": false,
      "capRegistry": false,
      "capResident": false,
      "capFellow": false,
      "capOther": false
    },
    "names": {
      "legal": {
        "firstName": "William",
        "lastName": "Chen"
      },
      "preferred": {
        "firstName": "Bill",
        "lastName": "Chen"
      }
    },
    "bio": {
      "text": "Bill Chen, M.D., is a Professor of Dermatology and Director of Mohs and Dermatologic Surgery."
    },
    "contacts": [
      {
        "address": "Tresidder Memorial Union,, 2nd Floor, Suite 4, 459 Lagunita Drive",
        "affiliationType": "University - Staff",
        "city": "Stanford",
        "department": "Res Ed Central Operations",
        "officeName": "office",
        "phoneNumbers": [
          "(650) 725-1234"
        ],
        "position": "Accountant",
        "state": "California",
        "type": "academic",
        "zip": "94305-3073"
      }
    ],
    "advisees": [{
      "advisee": {
        "alias": "bing-cao",
        "firstName": "Lyuqin",
        "lastName": "Cao",
        "profileId": 188882
      },
      "code": "PDFS",
      "role": "Postdoctoral Faculty Sponsor"
    }, {
      "advisee": {
        "alias": "lyuqin-chen",
        "firstName": "Bing",
        "lastName": "Chen",
        "profileId": 166179
      },
      "code": "PDFS",
      "role": "Postdoctoral Faculty Sponsor"
    }],
    "primaryContact": {
      "email": "billchen1@stanford.edu",
      "name": "Bill Chen",
      "phoneNumbers": ["(650) 725-1234"],
      "title": "Professor of Neurosurgery and of Psychiatry and Behavioral Sciences",
      "type": "primary"
    },
    "uid": "billchen1"
  }
JSON

STANFORD_PERSON_UPDATE = <<~JSON
  {
    "profileId": 400150,
    "affiliations": {
      "capFaculty": false,
      "capStaff": true,
      "capPostdoc": false,
      "capMdStudent": false,
      "capMsStudent": false,
      "capPhdStudent": false,
      "physician": false,
      "capRegistry": false,
      "capResident": false,
      "capFellow": false,
      "capOther": false
    },
    "names": {
      "legal": {
        "firstName": "William",
        "lastName": "Chen"
      },
      "preferred": {
        "firstName": "Billy",
        "middleName": "Edward",
        "lastName": "Chen"
      }
    },
    "bio": {
      "text": "Billy Chen, M.D., is a Professor of Dermatology and Director of Mohs and Dermatologic Surgery."
    },
    "contacts": [
      {
        "address": "Tresidder Memorial Union, 3rd Floor, Suite 4, 459 Lagunita Drive",
        "affiliationType": "University - Staff",
        "city": "Stanford",
        "department": "Res Ed Central Operations",
        "officeName": "office",
        "phoneNumbers": [
          "(650) 725-1234"
        ],
        "position": "Accountant",
        "state": "California",
        "type": "academic",
        "zip": "94305-3073"
      }
    ],
    "advisees": [{
      "advisee": {
        "alias": "rob-hale",
        "firstName": "Robert",
        "lastName": "Hale",
        "profileId": 34111
      },
      "code": "DRDR",
      "role": "Doctoral Dissertation Reader (AC)"
    }],
    "primaryContact": {
      "email": "billychen1@stanford.edu",
      "name": "Bill Chen",
      "phoneNumbers": ["(650) 725-1234"],
      "title": "Professor of Neurosurgery and of Psychiatry and Behavioral Sciences",
      "type": "primary"
    },
    "uid": "billchen1"
  }
JSON

RSpec.describe Rialto::Etl::Transformer do
  describe 'stanford_people_to_sparql_statements' do
    let(:repository) do
      RDF::Repository.new.tap do |repo|
        repo.insert(RDF::Statement.new(RDF::URI.new('foo'),
                                       RDF::URI.new('bar'),
                                       RDF::URI('foobar'),
                                       graph_name: Rialto::Etl::NamedGraphs::STANFORD_PEOPLE_GRAPH))
      end
    end

    let(:client) do
      SPARQL::Client.new(repository)
    end

    def transform(source)
      statements_io = StringIO.new

      transformer = Traject::Indexer.new.tap do |indexer|
        indexer.load_config_file('lib/rialto/etl/configs/stanford_people_to_sparql_statements.rb')
        indexer.settings['output_stream'] = statements_io
      end

      transformer.process(StringIO.new(source.delete("\n")))
      statement_reader = Rialto::Etl::Readers::SparqlStatementReader.new(StringIO.new(statements_io.string),
                                                                         'sparql_statement_reader.by_statement' => true)
      statement_reader.each do |statement|
        SPARQL.execute(statement, repository, update: true)
      end
    end

    describe 'insert' do
      before do
        transform(STANFORD_PERSON_INSERT)
      end

      # rubocop:disable RSpec/ExampleLength
      # rubocop:disable RSpec/MultipleExpectations
      it 'is inserted with person triples' do
        # Test 3 people
        query = client.select(count: { org: :c })
                      .from(Rialto::Etl::NamedGraphs::STANFORD_PEOPLE_GRAPH)
                      .where([:org, RDF.type, Rialto::Etl::Vocabs::FOAF['Person']])
                      .where([:org, RDF.type, Rialto::Etl::Vocabs::FOAF['Agent']])
        expect(query.solutions.first[:c].to_i).to eq(3)

        # Has valid date
        result = client.ask
                       .from(Rialto::Etl::NamedGraphs::STANFORD_PEOPLE_GRAPH)
                       .whether([Rialto::Etl::Vocabs::RIALTO_PEOPLE['400150'],
                                 Rialto::Etl::Vocabs::DCTERMS['valid'],
                                 RDF::Literal::Date.new(Time.now.to_date)])
                       .true?
        expect(result).to be true

        # Test label
        result = client.ask
                       .from(Rialto::Etl::NamedGraphs::STANFORD_PEOPLE_GRAPH)
                       .whether([Rialto::Etl::Vocabs::RIALTO_PEOPLE['400150'],
                                 Rialto::Etl::Vocabs::SKOS['prefLabel'],
                                 'Bill Chen'])
                       .true?
        expect(result).to be true

        # Test person name vcard
        result = client.ask
                       .from(Rialto::Etl::NamedGraphs::STANFORD_PEOPLE_GRAPH)
                       .whether([Rialto::Etl::Vocabs::RIALTO_PEOPLE['400150'],
                                 Rialto::Etl::Vocabs::VCARD['hasName'],
                                 Rialto::Etl::Vocabs::RIALTO_CONTEXT_NAMES['400150']])
                       .true?
        expect(result).to be true
        result = client.ask
                       .from(Rialto::Etl::NamedGraphs::STANFORD_PEOPLE_GRAPH)
                       .whether([Rialto::Etl::Vocabs::RIALTO_CONTEXT_NAMES['400150'],
                                 Rialto::Etl::Vocabs::VCARD['given-name'],
                                 'Bill'])
                       .whether([Rialto::Etl::Vocabs::RIALTO_CONTEXT_NAMES['400150'],
                                 Rialto::Etl::Vocabs::VCARD['family-name'],
                                 'Chen'])
                       .true?
        expect(result).to be true
        result = client.ask
                       .from(Rialto::Etl::NamedGraphs::STANFORD_PEOPLE_GRAPH)
                       .whether([Rialto::Etl::Vocabs::RIALTO_CONTEXT_NAMES['400150'],
                                 Rialto::Etl::Vocabs::VCARD['middle-name'],
                                 :o])
                       .true?
        expect(result).to be false

        # Test person affiliation
        result = client.ask
                       .from(Rialto::Etl::NamedGraphs::STANFORD_PEOPLE_GRAPH)
                       .whether([Rialto::Etl::Vocabs::RIALTO_PEOPLE['400150'],
                                 RDF.type,
                                 Rialto::Etl::Vocabs::VIVO['FacultyMember']])
                       .true?
        expect(result).to be true
        result = client.ask
                       .from(Rialto::Etl::NamedGraphs::STANFORD_PEOPLE_GRAPH)
                       .whether([Rialto::Etl::Vocabs::RIALTO_PEOPLE['400150'],
                                 RDF.type,
                                 Rialto::Etl::Vocabs::VIVO['Student']])
                       .true?
        expect(result).to be false

        # Test person biograph
        result = client.ask
                       .from(Rialto::Etl::NamedGraphs::STANFORD_PEOPLE_GRAPH)
                       .whether([Rialto::Etl::Vocabs::RIALTO_PEOPLE['400150'],
                                 Rialto::Etl::Vocabs::VIVO['overview'],
                                 'Bill Chen, M.D., is a Professor of Dermatology and Director of Mohs and '\
                                 'Dermatologic Surgery.'])
                       .true?
        expect(result).to be true

        # Test person address vcard
        result = client.ask
                       .from(Rialto::Etl::NamedGraphs::STANFORD_PEOPLE_GRAPH)
                       .whether([Rialto::Etl::Vocabs::RIALTO_PEOPLE['400150'],
                                 Rialto::Etl::Vocabs::VCARD['hasAddress'],
                                 Rialto::Etl::Vocabs::RIALTO_CONTEXT_ADDRESSES['400150']])
                       .true?
        expect(result).to be true
        result = client.ask
                       .from(Rialto::Etl::NamedGraphs::STANFORD_PEOPLE_GRAPH)
                       .whether([Rialto::Etl::Vocabs::RIALTO_CONTEXT_ADDRESSES['400150'],
                                 RDF.type,
                                 Rialto::Etl::Vocabs::VCARD['Address']])
                       .whether([Rialto::Etl::Vocabs::RIALTO_CONTEXT_ADDRESSES['400150'],
                                 Rialto::Etl::Vocabs::VCARD['street-address'],
                                 'Tresidder Memorial Union,, 2nd Floor, Suite 4, 459 Lagunita Drive'])
                       .whether([Rialto::Etl::Vocabs::RIALTO_CONTEXT_ADDRESSES['400150'],
                                 Rialto::Etl::Vocabs::VCARD['locality'],
                                 'Stanford'])
                       .whether([Rialto::Etl::Vocabs::RIALTO_CONTEXT_ADDRESSES['400150'],
                                 Rialto::Etl::Vocabs::VCARD['region'],
                                 'California'])
                       .whether([Rialto::Etl::Vocabs::RIALTO_CONTEXT_ADDRESSES['400150'],
                                 Rialto::Etl::Vocabs::VCARD['postal-code'],
                                 '94305-3073'])
                       .whether([Rialto::Etl::Vocabs::RIALTO_CONTEXT_ADDRESSES['400150'],
                                 Rialto::Etl::Vocabs::VCARD['country-name'],
                                 'United States'])
                       .whether([Rialto::Etl::Vocabs::RIALTO_CONTEXT_ADDRESSES['400150'],
                                 Rialto::Etl::Vocabs::DCTERMS['spatial'],
                                 RDF::URI.new('http://sws.geonames.org/6252001/')])
                       .true?
        expect(result).to be true

        # Test advisee label
        result = client.ask
                       .from(Rialto::Etl::NamedGraphs::STANFORD_PEOPLE_GRAPH)
                       .whether([Rialto::Etl::Vocabs::RIALTO_PEOPLE['188882'],
                                 Rialto::Etl::Vocabs::SKOS['prefLabel'],
                                 'Lyuqin Cao'])
                       .true?
        expect(result).to be true

        # Test advisee name vcard
        result = client.ask
                       .from(Rialto::Etl::NamedGraphs::STANFORD_PEOPLE_GRAPH)
                       .whether([Rialto::Etl::Vocabs::RIALTO_PEOPLE['188882'],
                                 Rialto::Etl::Vocabs::VCARD['hasName'],
                                 Rialto::Etl::Vocabs::RIALTO_CONTEXT_NAMES['188882']])
                       .true?
        expect(result).to be true
        result = client.ask
                       .from(Rialto::Etl::NamedGraphs::STANFORD_PEOPLE_GRAPH)
                       .whether([Rialto::Etl::Vocabs::RIALTO_CONTEXT_NAMES['188882'],
                                 Rialto::Etl::Vocabs::VCARD['given-name'],
                                 'Lyuqin'])
                       .whether([Rialto::Etl::Vocabs::RIALTO_CONTEXT_NAMES['188882'],
                                 Rialto::Etl::Vocabs::VCARD['family-name'],
                                 'Cao'])
                       .true?
        expect(result).to be true

        # Test advising relationship
        result = client.ask
                       .from(Rialto::Etl::NamedGraphs::STANFORD_PEOPLE_GRAPH)
                       .whether([Rialto::Etl::Vocabs::RIALTO_CONTEXT_RELATIONSHIPS['188882_400150'],
                                 RDF.type,
                                 Rialto::Etl::Vocabs::VIVO['AdvisingRelationship']])
                       .whether([Rialto::Etl::Vocabs::RIALTO_CONTEXT_RELATIONSHIPS['188882_400150'],
                                 Rialto::Etl::Vocabs::DCTERMS['valid'],
                                 RDF::Literal::Date.new(Time.now.to_date)])
                       .whether([Rialto::Etl::Vocabs::RIALTO_PEOPLE['188882'],
                                 Rialto::Etl::Vocabs::VIVO['relatedBy'],
                                 Rialto::Etl::Vocabs::RIALTO_CONTEXT_RELATIONSHIPS['188882_400150']])
                       .whether([Rialto::Etl::Vocabs::RIALTO_PEOPLE['400150'],
                                 Rialto::Etl::Vocabs::VIVO['relatedBy'],
                                 Rialto::Etl::Vocabs::RIALTO_CONTEXT_RELATIONSHIPS['188882_400150']])
                       .true?
        expect(result).to be true

        # Test advising role
        result = client.ask
                       .from(Rialto::Etl::NamedGraphs::STANFORD_PEOPLE_GRAPH)
                       .whether([Rialto::Etl::Vocabs::RIALTO_CONTEXT_ROLES['AdvisorRole'],
                                 RDF.type,
                                 Rialto::Etl::Vocabs::VIVO['AdvisorRole']])
                       .whether([Rialto::Etl::Vocabs::RIALTO_PEOPLE['400150'],
                                 Rialto::Etl::Vocabs::OBO['RO_0000053'],
                                 Rialto::Etl::Vocabs::RIALTO_CONTEXT_ROLES['AdvisorRole']])
                       .whether([Rialto::Etl::Vocabs::RIALTO_CONTEXT_ROLES['AdvisorRole'],
                                 Rialto::Etl::Vocabs::OBO['RO_0000052'],
                                 Rialto::Etl::Vocabs::RIALTO_PEOPLE['400150']])
                       .true?
        expect(result).to be true

        # Test advisee role
        result = client.ask
                       .from(Rialto::Etl::NamedGraphs::STANFORD_PEOPLE_GRAPH)
                       .whether([Rialto::Etl::Vocabs::RIALTO_CONTEXT_ROLES['AdviseeRole'],
                                 RDF.type,
                                 Rialto::Etl::Vocabs::VIVO['AdviseeRole']])
                       .whether([Rialto::Etl::Vocabs::RIALTO_PEOPLE['188882'],
                                 Rialto::Etl::Vocabs::OBO['RO_0000053'],
                                 Rialto::Etl::Vocabs::RIALTO_CONTEXT_ROLES['AdviseeRole']])
                       .whether([Rialto::Etl::Vocabs::RIALTO_CONTEXT_ROLES['AdviseeRole'],
                                 Rialto::Etl::Vocabs::OBO['RO_0000052'],
                                 Rialto::Etl::Vocabs::RIALTO_PEOPLE['188882']])
                       .true?
        expect(result).to be true

        # Test person email
        result = client.ask
                       .from(Rialto::Etl::NamedGraphs::STANFORD_PEOPLE_GRAPH)
                       .whether([Rialto::Etl::Vocabs::RIALTO_PEOPLE['400150'],
                                 Rialto::Etl::Vocabs::VCARD['hasEmail'],
                                 'billchen1@stanford.edu'])
                       .true?
        expect(result).to be true

        # Test sunetid
        result = client.ask
                       .from(Rialto::Etl::NamedGraphs::STANFORD_PEOPLE_GRAPH)
                       .whether([Rialto::Etl::Vocabs::RIALTO_PEOPLE['400150'],
                                 Rialto::Etl::Vocabs::DCTERMS['identifier'],
                                 RDF::Literal.new('billchen1',
                                                  datatype: Rialto::Etl::Vocabs::RIALTO_CONTEXT_IDENTIFIERS['Sunetid'])])
                       .true?
        expect(result).to be true
      end
      # rubocop:enable RSpec/ExampleLength
      # rubocop:enable RSpec/MultipleExpectations
    end
    describe 'update person' do
      before do
        transform(STANFORD_PERSON_INSERT)
        transform(STANFORD_PERSON_UPDATE)
      end

      # rubocop:disable RSpec/ExampleLength
      # rubocop:disable RSpec/MultipleExpectations
      it 'updates the person' do
        # Test 4 people (removed 2 advisees and added one)
        query = client.select(count: { org: :c })
                      .from(Rialto::Etl::NamedGraphs::STANFORD_PEOPLE_GRAPH)
                      .where([:org, RDF.type, Rialto::Etl::Vocabs::FOAF['Person']])
                      .where([:org, RDF.type, Rialto::Etl::Vocabs::FOAF['Agent']])
        expect(query.solutions.first[:c].to_i).to eq(4)

        # Test label
        result = client.ask
                       .from(Rialto::Etl::NamedGraphs::STANFORD_PEOPLE_GRAPH)
                       .whether([Rialto::Etl::Vocabs::RIALTO_PEOPLE['400150'],
                                 Rialto::Etl::Vocabs::SKOS['prefLabel'],
                                 'Billy Edward Chen'])
                       .true?
        expect(result).to be true

        # Test name changed
        result = client.ask
                       .from(Rialto::Etl::NamedGraphs::STANFORD_PEOPLE_GRAPH)
                       .whether([Rialto::Etl::Vocabs::RIALTO_CONTEXT_NAMES['400150'],
                                 Rialto::Etl::Vocabs::VCARD['given-name'],
                                 'Billy'])
                       .whether([Rialto::Etl::Vocabs::RIALTO_CONTEXT_NAMES['400150'],
                                 Rialto::Etl::Vocabs::VCARD['middle-name'],
                                 'Edward'])
                       .whether([Rialto::Etl::Vocabs::RIALTO_CONTEXT_NAMES['400150'],
                                 Rialto::Etl::Vocabs::VCARD['family-name'],
                                 'Chen'])
                       .true?
        expect(result).to be true

        # Test person affiliation changed
        result = client.ask
                       .from(Rialto::Etl::NamedGraphs::STANFORD_PEOPLE_GRAPH)
                       .whether([Rialto::Etl::Vocabs::RIALTO_PEOPLE['400150'],
                                 RDF.type,
                                 Rialto::Etl::Vocabs::VIVO['NonAcademic']])
                       .true?
        expect(result).to be true
        result = client.ask
                       .from(Rialto::Etl::NamedGraphs::STANFORD_PEOPLE_GRAPH)
                       .whether([Rialto::Etl::Vocabs::RIALTO_PEOPLE['400150'],
                                 RDF.type,
                                 Rialto::Etl::Vocabs::VIVO['FacultyMember']])
                       .true?
        expect(result).to be false

        # Test person biograph changed
        result = client.ask
                       .from(Rialto::Etl::NamedGraphs::STANFORD_PEOPLE_GRAPH)
                       .whether([Rialto::Etl::Vocabs::RIALTO_PEOPLE['400150'],
                                 Rialto::Etl::Vocabs::VIVO['overview'],
                                 'Billy Chen, M.D., is a Professor of Dermatology and Director of Mohs '\
                                 'and Dermatologic Surgery.'])
                       .true?
        expect(result).to be true

        # Test person address vcard changed
        result = client.ask
                       .from(Rialto::Etl::NamedGraphs::STANFORD_PEOPLE_GRAPH)
                       .whether([Rialto::Etl::Vocabs::RIALTO_CONTEXT_ADDRESSES['400150'],
                                 RDF.type,
                                 Rialto::Etl::Vocabs::VCARD['Address']])
                       .whether([Rialto::Etl::Vocabs::RIALTO_CONTEXT_ADDRESSES['400150'],
                                 Rialto::Etl::Vocabs::VCARD['street-address'],
                                 'Tresidder Memorial Union, 3rd Floor, Suite 4, 459 Lagunita Drive'])
                       .whether([Rialto::Etl::Vocabs::RIALTO_CONTEXT_ADDRESSES['400150'],
                                 Rialto::Etl::Vocabs::VCARD['locality'],
                                 'Stanford'])
                       .whether([Rialto::Etl::Vocabs::RIALTO_CONTEXT_ADDRESSES['400150'],
                                 Rialto::Etl::Vocabs::VCARD['region'],
                                 'California'])
                       .whether([Rialto::Etl::Vocabs::RIALTO_CONTEXT_ADDRESSES['400150'],
                                 Rialto::Etl::Vocabs::VCARD['postal-code'],
                                 '94305-3073'])
                       .whether([Rialto::Etl::Vocabs::RIALTO_CONTEXT_ADDRESSES['400150'],
                                 Rialto::Etl::Vocabs::VCARD['country-name'],
                                 'United States'])
                       .whether([Rialto::Etl::Vocabs::RIALTO_CONTEXT_ADDRESSES['400150'],
                                 Rialto::Etl::Vocabs::DCTERMS['spatial'],
                                 RDF::URI.new('http://sws.geonames.org/6252001/')])
                       .true?
        expect(result).to be true

        # Test person email
        result = client.ask
                       .from(Rialto::Etl::NamedGraphs::STANFORD_PEOPLE_GRAPH)
                       .whether([Rialto::Etl::Vocabs::RIALTO_PEOPLE['400150'],
                                 Rialto::Etl::Vocabs::VCARD['hasEmail'],
                                 'billychen1@stanford.edu'])
                       .true?
        expect(result).to be true
      end
      # rubocop:enable RSpec/ExampleLength
      # rubocop:enable RSpec/MultipleExpectations
    end
  end
end