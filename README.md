# Rialto::Etl

[![Gem](https://img.shields.io/gem/v/rialto-etl.svg)](https://rubygems.org/gems/rialto-etl)
[![Travis](https://img.shields.io/travis/sul-dlss-labs/rialto-etl.svg)](https://travis-ci.org/sul-dlss-labs/rialto-etl)
[![Code Climate maintainability](https://img.shields.io/codeclimate/maintainability/sul-dlss-labs/rialto-etl.svg)](https://codeclimate.com/github/sul-dlss-labs/rialto-etl/maintainability)
[![Code Climate coverage](https://img.shields.io/codeclimate/coverage/sul-dlss-labs/rialto-etl.svg)](https://codeclimate.com/github/sul-dlss-labs/rialto-etl/coverage)
[![Documentation](https://inch-ci.org/github/sul-dlss-labs/rialto-etl.svg?branch=master)](https://inch-ci.org/github/sul-dlss-labs/rialto-etl)
[![API](http://img.shields.io/badge/API-docs-blue.svg)](http://rubydoc.info/gems/rialto-etl)
[![Apache 2.0 License](http://img.shields.io/badge/APACHE2-license-blue.svg)](./LICENSE)

Rialto::Etl is a set of ETL tools for RIALTO, Stanford University Libraries' research intelligence project

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rialto-etl'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install rialto-etl

## Usage

### Pipeline to ingest organizations into Rialto

```
exe/extract call StanfordOrganizations > step1.json
exe/transform call StanfordOrganizationsToVivo -i step1.json > step2.nt
exe/load call Sparql -i step2.nt
```

### Extract

#### Authentication

If you are using the `StanfordResearchers` or `StanfordOrganizations` extract methods, you will first need to obtain a token for the CAP API and set the `Settings.tokens.cap` value to this token. To set this value, either set an environment variable named `SETTINGS__TOKENS__CAP` or add the value for this to `config/settings.local.yml` (which is ignored under version control and should never be checked in), like so:


```yaml
tokens:
  cap: 'foobar'
```

### Run the extract process
Run `exe/extract` to run a named extractor and print output to STDOUT:

    $ exe/extract call StanfordResearchers
    {"count":10,"firstPage":true,"lastPage":false,"page":1,"totalCount":29089,"totalPages":2909,"values":[{"administrativeAppointments":[...

### List registered extract processes

Run `exe/extract list` to print out the list of callable extractors.


### Transform

Run `exe/transform` to run a named transformer, based on [Traject](https://github.com/traject/traject), on a named input file and print output to STDOUT:

    $ exe/transform call StanfordOrganizationsToVivo -i stanford_organizations.json
    {"@id":"http://authorities.stanford.edu/orgs#vice-provost-for-undergraduate-education/stanford-introductory-studies/freshman-and-sophomore-programs","@type":"http://vivoweb.org/ontology/core#Division","rdfs:label":"Freshman and Sophomore Programs","vivo:abbreviation":["FFQH"]}

Run `exe/transform list` to print out the list of callable transformers.

### Load

TBD

## Configuration

Rialto::Etl uses the [config gem](https://github.com/railsconfig/config) to manage configuration, allowing for flexible variation of configs between environments and hosts. By default, the gem assumes it is running in the `'production'` environment and will look for its configurations per the [config gem documentation](https://github.com/railsconfig/config#accessing-the-settings-object). To explicitly set the environment to `test` or `development`, set an environment variable named `ENV`.

## Help

    $ exe/extract help
    Commands:
      extract call NAME       # Call named extractor (`extract list` to see available names)
      extract help [COMMAND]  # Describe subcommands or one specific subcommand
      extract list            # List callable extractors

    $ exe/transform help
    Commands:
      transform call NAME       # Call named transformer (`transform list` to see available names)
      transform help [COMMAND]  # Describe subcommands or one specific subcommand
      transform list            # List callable transformers

## Documentation

* [Mapping / Mapping Target](./mapping.md)
* [CAP Organizations to VIVO Mapping](./docs/CAP-organizations.md)

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Sample Data

The sample data we use to work with Rialto::Etl is contained in a private Github repository and included here as a Git submodule.
To use the `sample_data` submodule, run the following (after cloning the project locally):

    $rialto-etl> git submodule init
    Submodule 'sample_data' (git@github.com:sul-dlss/rialto-sample-data.git) registered for path 'sample_data'
    $rialto-etl> git submodule update
    Cloning into 'Projects/rialto-etl/sample_data'...
    Submodule path 'sample_data': checked out '{some hash...}'

Now the sample data can be accessed from the relative path, e.g. `$rialto-etl> cat sample_data/mapped/departments.rdf`.
In order to update `sample_data` locally with any upstream changes, from the project root run:

    $ git submodule update --remote

You can also modify the `sample_data` repo directly from within this project. For more details, see the "Working on a Project with Submodules" section of
https://git-scm.com/book/en/v2/Git-Tools-Submodules.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/sul-dlss-labs/rialto-etl.
