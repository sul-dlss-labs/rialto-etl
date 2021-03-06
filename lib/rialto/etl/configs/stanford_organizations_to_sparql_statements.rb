# frozen_string_literal: true

require 'traject_plus'
require 'rialto/etl/readers/stanford_organizations_json_reader'
require 'rialto/etl/writers/sparql_statement_writer'
require 'rialto/etl/namespaces'

extend TrajectPlus::Macros
extend TrajectPlus::Macros::JSON
extend Rialto::Etl::NamedGraphs
extend Rialto::Etl::Vocabs
extend Rialto::Etl::Logging

ORGS_NEEDING_CONTEXT = ['External Relations',
                        'Administration',
                        "Dean's Office",
                        'Financial Aid',
                        'Financial Aid Office',
                        'Research Centers'].freeze

def contextualized_org_name(organization)
  if ORGS_NEEDING_CONTEXT.include?(organization['name']) && !organization['parent'].nil?
    return "#{organization['name']} (#{organization['parent']['name']})"
  end
  organization['name']
end

self.logger = logger

settings do
  provide 'writer_class_name', 'Rialto::Etl::Writers::SparqlStatementWriter'
  provide 'reader_class_name', 'Rialto::Etl::Readers::StanfordOrganizationsJsonReader'
end

# The named graph to place these triples into.
to_field '@graph', literal(STANFORD_ORGANIZATIONS_GRAPH.to_s), single: true

# Subject
to_field '@id', lambda { |json, accum|
  accum << RIALTO_ORGANIZATIONS[json['alias']]
}, single: true

# Org types
to_field '@type', lambda { |json, accum|
  org_types = [RDF::Vocab::FOAF.Agent, RDF::Vocab::FOAF.Organization]
  org_types << case JsonPath.on(json, '$.type').first
               when 'DIVISION', 'SUB_DIVISION'
                 # Division or institute
                 VIVO[Traject::TranslationMap.new('stanford_departments_to_vivo_types', default: 'Division')[json['alias']]]
               when 'ROOT'
                 VIVO.University
               when 'SCHOOL'
                 VIVO.School
               else
                 # Department or Institute
                 VIVO[Traject::TranslationMap.new('stanford_departments_to_vivo_types', default: 'Department')[json['alias']]]
               end
  accum.concat(org_types)
}

# Org label
to_field '!' + RDF::Vocab::SKOS.prefLabel.to_s, literal(true)
to_field RDF::Vocab::SKOS.prefLabel.to_s, lambda { |json, accum|
  accum << contextualized_org_name(json)
}
to_field "!#{RDF::Vocab::RDFS.label}", literal(true)
to_field RDF::Vocab::RDFS.label.to_s, lambda { |json, accum|
  accum << contextualized_org_name(json)
}

# Org codes
to_field '!' + RDF::Vocab::DC.identifier.to_s, literal(true)
to_field RDF::Vocab::DC.identifier.to_s, extract_json('$.orgCodes'), single: true

# Parent
to_field "!#{OBO.BFO_0000050}", literal(true)
to_field OBO.BFO_0000050.to_s, lambda { |json, accum|
  parent = JsonPath.on(json, '$.parent.alias').first
  accum << RIALTO_ORGANIZATIONS[parent] if parent
}
