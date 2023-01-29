# SchXslt Redux XSLT2

A feature complete implementation of an XSLT 2.0 ISO Schematron processor for the XSLT 2.0 query language binding.

SchXslt Redux XSLT2 is copyright (c) 2018-2023 by David Maus and released under the terms of the MIT license.

## About

This is a trimmed down version of the XSLT 2.0 processor of SchXslt. The processor is implemend as a single XSLT
transformation that transpile a ISO Schematron schema to an XSLT validation stylesheet. The validation stylesheet
creates a SVRL report when applied to a document instance.

SchXslt Redux XSLT2 is a *strict* implementation of ISO Schematron. If you switch from a different implementation such
as [SchXslt](https://github.com/schxslt/schxslt) or the ["Skeleton"](https://github.com/schematron/schematron) your
schema files might not work as expected.

Feel free to contact me if you need help getting your Schematron standard-compliant.

## Limitations

SchXslt Redux XSLT2 comes with the following limitations.

Schematron variables scoped to a phase or pattern are promoted to global XSLT variables.

## Installation and Usage

The [Github releases page](https://github.com/schxslt/schxslt-redux-xslt2/releases) provides a ZIP file with the
processor stylesheets. Download and unzip the file in an appropriate location. Users of [eXist](https://existdb.org) and
[BaseX](https://basex.org) can download and import an EXPath package from the [releases
page](https://github.com/schxslt/schxslt-redux-xslt2/releases), too.

Java users can use the artifact ```name.dmaus.schxslt.schxslt-redux-xslt2``` from Maven Central.

## Authors

David Maus &lt;dmaus@dmaus.name&gt;
