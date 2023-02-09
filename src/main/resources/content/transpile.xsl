<!--
Copyright (C) 2023 by David Maus <dmaus@dmaus.name>

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use, copy,
modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
-->
<xsl:transform version="2.0"
               xmlns:alias="http://www.w3.org/1999/XSL/TransformAlias"
               xmlns:redux="https://doi.org/10.5281/zenodo.7368576"
               xmlns:sch="http://purl.oclc.org/dsdl/schematron"
               xmlns:svrl="http://purl.oclc.org/dsdl/svrl"
               xmlns:xs="http://www.w3.org/2001/XMLSchema"
               xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:output indent="yes"/>

  <xsl:namespace-alias stylesheet-prefix="alias" result-prefix="xsl"/>

  <xsl:param name="phase" as="xs:string">#DEFAULT</xsl:param>

  <xsl:key name="patternByPhase" match="sch:pattern" use="../sch:phase[current()/@id = sch:active/@pattern]/@id"/>
  <xsl:key name="patternByPhase" match="sch:pattern" use="'#ALL'"/>
  <xsl:key name="diagnosticById" match="sch:diagnostic" use="@id"/>
  <xsl:key name="propertyById" match="sch:property" use="@id"/>

  <xsl:template match="sch:schema" as="element(xsl:transform)">
    <xsl:variable name="phase-1-include" as="document-node(element(sch:schema))">
      <xsl:document>
        <xsl:apply-templates select="." mode="include"/>
      </xsl:document>
    </xsl:variable>
    <xsl:variable name="phase-2-expand" as="document-node(element(sch:schema))">
      <xsl:document>
        <xsl:apply-templates select="$phase-1-include" mode="expand"/>
      </xsl:document>
    </xsl:variable>
    <xsl:apply-templates select="$phase-2-expand" mode="transpile"/>
  </xsl:template>

  <!-- Include -->
  <xsl:template match="sch:include" as="element()" mode="include">
    <xsl:apply-templates select="document(@href)" mode="#current">
      <xsl:with-param name="sourceLanguage" select="redux:in-scope-language(.)"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="sch:rule/sch:extends[@href]" as="node()*" mode="include">
    <xsl:variable name="external" as="element()" select="if (document(@href) instance of document-node()) then document(@href)/*[1] else document(@href)"/>
    <xsl:if test="(namespace-uri($external) ne 'http://purl.oclc.org/dsdl/schematron') or (local-name($external) ne 'rule')">
      <xsl:variable name="message" as="xs:string+">
        The @href attribute of an &lt;extends&gt; element must be an
        IRI reference to an external well-formed XML document or to an
        element in an external well-formed XML document that is a
        Schematron &lt;rule&gt; element. This @href points to a
        <xsl:value-of select="concat('Q{', namespace-uri($external), '}', local-name($external))"/>
        element.
      </xsl:variable>
      <xsl:message terminate="yes">
        <xsl:text/>
        <xsl:value-of select="normalize-space(string-join($message, ''))"/>
      </xsl:message>
    </xsl:if>
    <xsl:apply-templates select="$external/node()" mode="#current">
      <xsl:with-param name="sourceLanguage" select="redux:in-scope-language(.)"/>
    </xsl:apply-templates>
  </xsl:template>

  <!-- Expand -->
  <xsl:template match="sch:rule[@abstract = 'true']" as="empty-sequence()" mode="expand"/>
  <xsl:template match="sch:rule/sch:extends[@rule]" as="node()*" mode="expand">
    <xsl:if test="empty(../../sch:rule[@abstract = 'true'][@id = current()/@rule])">
      <xsl:variable name="message" as="xs:string+">
        The current pattern defines no abstract rule named '<xsl:value-of select="@rule"/>'.
      </xsl:variable>
      <xsl:message terminate="yes">
        <xsl:text/>
        <xsl:value-of select="normalize-space(string-join($message, ''))"/>
      </xsl:message>
    </xsl:if>
    <xsl:apply-templates select="../../sch:rule[@abstract = 'true'][@id = current()/@rule]/node()" mode="#current">
      <xsl:with-param name="sourceLanguage" as="xs:string" select="redux:in-scope-language(.)"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="sch:pattern[@abstract = 'true']" as="empty-sequence()" mode="expand"/>
  <xsl:template match="sch:pattern[@is-a]" as="element(sch:pattern)" mode="expand">
    <xsl:variable name="is-a" as="element(sch:pattern)?" select="../sch:pattern[@abstract = 'true'][@id = current()/@is-a]"/>
    <xsl:if test="empty($is-a)">
      <xsl:variable name="message" as="xs:string+">
        The current schema does not define an abstract pattern with an id of <xsl:value-of select="@is-a"/>.
      </xsl:variable>
      <xsl:message terminate="yes">
        <xsl:text/>
        <xsl:value-of select="normalize-space(string-join($message, ''))"/>
      </xsl:message>
    </xsl:if>

    <xsl:variable name="instance" as="node()*">
      <xsl:document>
        <xsl:apply-templates select="$is-a/node()" mode="#current">
          <xsl:with-param name="sourceLanguage" as="xs:string" select="redux:in-scope-language(.)"/>
          <xsl:with-param name="params" as="element(sch:param)*" select="sch:param" tunnel="yes"/>
        </xsl:apply-templates>
      </xsl:document>
    </xsl:variable>

    <xsl:variable name="diagnostics" as="xs:string*" select="tokenize(string-join($instance/sch:rule/sch:*/@diagnostics, ' '), '\s+')"/>
    <xsl:variable name="properties" as="xs:string*" select="tokenize(string-join($instance/sch:rule/sch:*/@properties, ' '), '\s+')"/>

    <xsl:copy>
      <xsl:apply-templates select="@*" mode="#current">
        <xsl:with-param name="params" as="element(sch:param)*" select="sch:param" tunnel="yes"/>
      </xsl:apply-templates>
      <xsl:if test="empty(@documents)">
        <xsl:apply-templates select="$is-a/@documents" mode="#current">
          <xsl:with-param name="params" as="element(sch:param)*" select="sch:param" tunnel="yes"/>
        </xsl:apply-templates>
      </xsl:if>
      <xsl:if test="empty(@xml:lang) and (redux:in-scope-language(.) ne redux:in-scope-language($is-a))">
        <xsl:attribute name="xml:lang" select="redux:in-scope-language($is-a)"/>
      </xsl:if>
      <xsl:sequence select="$instance"/>
      <xsl:apply-templates select="node()" mode="#current"/>

      <xsl:if test="exists($diagnostics)">
        <xsl:element name="diagnostics" namespace="http://purl.oclc.org/dsdl/schematron">
          <xsl:apply-templates select="key('diagnosticById', $diagnostics)" mode="#current">
            <xsl:with-param name="params" as="element(sch:param)*" select="sch:param" tunnel="yes"/>
          </xsl:apply-templates>
        </xsl:element>
      </xsl:if>
      <xsl:if test="exists($properties)">
        <xsl:element name="properties" namespace="http://purl.oclc.org/dsdl/schematron">
          <xsl:apply-templates select="key('propertyById', $properties)" mode="#current">
            <xsl:with-param name="params" as="element(sch:param)*" select="sch:param" tunnel="yes"/>
          </xsl:apply-templates>
        </xsl:element>
      </xsl:if>

    </xsl:copy>

  </xsl:template>

  <xsl:template match="sch:assert/@test | sch:report/@test | sch:rule/@context | sch:value-of/@select | sch:pattern/@documents | sch:name/@path | sch:let/@value | xsl:copy-of[ancestor::sch:property]/@select" mode="expand">
    <xsl:param name="params" as="element(sch:param)*" tunnel="yes"/>
    <xsl:attribute name="{name()}" select="redux:replace-params(., $params)"/>
  </xsl:template>

  <xsl:function name="redux:replace-params" as="xs:string?">
    <xsl:param name="src" as="xs:string"/>
    <xsl:param name="params" as="element(sch:param)*"/>
    <xsl:choose>
      <xsl:when test="empty($params)">
        <xsl:value-of select="$src"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="paramsSorted" as="element(sch:param)*">
          <xsl:for-each select="$params">
            <xsl:sort select="string-length(@name)" order="descending"/>
            <xsl:sequence select="."/>
          </xsl:for-each>
        </xsl:variable>

        <xsl:variable name="value" select="replace(replace($paramsSorted[1]/@value, '\\', '\\\\'), '\$', '\\\$')"/>
        <xsl:variable name="src" select="replace($src, concat('(\W*)\$', $paramsSorted[1]/@name, '(\W*)'), concat('$1', $value, '$2'))"/>
        <xsl:value-of select="redux:replace-params($src, $paramsSorted[position() > 1])"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <!-- Transpile -->

  <xsl:template match="sch:schema" as="element(xsl:transform)" mode="transpile">
    <xsl:variable name="queryBinding" as="xs:string?" select="@queryBinding"/>

    <xsl:if test="not($queryBinding = 'xslt2')">
      <xsl:variable name="message" as="xs:string+">
        This Schematron processor only supports the XSLT 2.0 query binding.
      </xsl:variable>
      <xsl:message terminate="yes">
        <xsl:text/>
        <xsl:value-of select="normalize-space(string-join($message, ''))"/>
      </xsl:message>
    </xsl:if>

    <xsl:variable name="phase" as="xs:string">
      <xsl:choose>
        <xsl:when test="($phase = '#DEFAULT') or ($phase = '')">
          <xsl:choose>
            <xsl:when test="@defaultPhase">
              <xsl:value-of select="@defaultPhase"/>
            </xsl:when>
            <xsl:otherwise>#ALL</xsl:otherwise>
          </xsl:choose>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$phase"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>

    <xsl:if test="not($phase = '#ALL') and not(sch:phase[@id = $phase])">
      <xsl:variable name="message" as="xs:string+">
        The phase <xsl:value-of select="$phase"/> is not defined.
      </xsl:variable>
      <xsl:message terminate="yes">
        <xsl:text/>
        <xsl:value-of select="normalize-space(string-join($message, ''))"/>
      </xsl:message>
    </xsl:if>

    <alias:transform version="2.0">
      <xsl:for-each select="sch:ns">
        <xsl:namespace name="{@prefix}" select="@uri"/>
      </xsl:for-each>

      <xsl:call-template name="declare-variables">
        <xsl:with-param name="variables" as="element(sch:let)*" select="sch:let"/>
        <xsl:with-param name="declName" select="'param'"/>
      </xsl:call-template>

      <xsl:call-template name="declare-variables">
        <xsl:with-param name="variables" as="element(sch:let)*" select="sch:phase[@id = $phase]/sch:let"/>
      </xsl:call-template>

      <xsl:call-template name="declare-variables">
        <xsl:with-param name="variables" as="element(sch:let)*" select="key('patternByPhase', $phase)/sch:let"/>
      </xsl:call-template>

      <xsl:sequence select="xsl:key[not(preceding-sibling::sch:pattern)]"/>
      <xsl:sequence select="xsl:function[not(preceding-sibling::sch:pattern)]"/>

      <alias:template match="/">
        <svrl:schematron-output>
          <xsl:for-each-group select="key('patternByPhase', $phase)" group-by="string(@documents)">
            <alias:call-template name="{generate-id()}"/>
          </xsl:for-each-group>
        </svrl:schematron-output>
      </alias:template>

      <xsl:for-each-group select="key('patternByPhase', $phase)" group-by="string(@documents)">
        <xsl:variable name="mode" as="xs:string" select="generate-id()"/>

        <alias:template name="{$mode}">
          <svrl:active-pattern>
            <xsl:sequence select="@id"/>
            <alias:attribute name="documents" select="{if (@documents) then @documents else 'document-uri(.)'}"/>
          </svrl:active-pattern>

          <xsl:choose>
            <xsl:when test="@documents">
              <alias:for-each select="{@documents}">
                <alias:apply-templates mode="{$mode}" select="document(.)"/>
              </alias:for-each>
            </xsl:when>
            <xsl:otherwise>
              <alias:apply-templates mode="{$mode}" select="."/>
            </xsl:otherwise>
          </xsl:choose>

        </alias:template>

        <xsl:apply-templates select="current-group()/sch:rule" mode="#current">
          <xsl:with-param name="mode" as="xs:string" select="$mode"/>
        </xsl:apply-templates>

      </xsl:for-each-group>

      <alias:template match="text()" mode="#all" priority="-10"/>
      <alias:template match="/" mode="#all" priority="-10">
        <alias:apply-templates mode="#current" select="node()"/>
      </alias:template>
      <alias:template match="*" mode="#all" priority="-10">
        <alias:apply-templates mode="#current" select="@*"/>
        <alias:apply-templates mode="#current" select="node()"/>
      </alias:template>

      <xsl:apply-templates select="document('location.xsl')/xsl:transform/xsl:function" mode="copy-location-function"/>

    </alias:transform>

  </xsl:template>

  <xsl:template match="sch:rule" mode="transpile" as="element(xsl:template)">
    <xsl:param name="mode" as="xs:string" required="true"/>
    <alias:template match="{@context}" mode="{$mode}">
      <alias:param name="redux:pattern" as="xs:string*" select="()"/>

      <alias:choose>
        <alias:when test="'{generate-id(..)}' = $redux:pattern">
          <alias:next-match>
            <alias:with-param name="redux:pattern" as="xs:string+" select="$redux:pattern"/>
          </alias:next-match>
        </alias:when>
        <alias:otherwise>
          <svrl:fired-rule>
            <xsl:sequence select="@id"/>
            <xsl:sequence select="@role"/>
            <xsl:sequence select="@flag"/>
            <xsl:sequence select="@context"/>
            <alias:if test="document-uri()">
              <alias:attribute name="document" select="document-uri()"/>
            </alias:if>
          </svrl:fired-rule>
          <xsl:call-template name="declare-variables">
            <xsl:with-param name="variables" select="sch:let"/>
          </xsl:call-template>
          <xsl:apply-templates select="sch:assert | sch:report" mode="#current"/>
          <alias:next-match>
            <alias:with-param name="redux:pattern" as="xs:string+" select="('{generate-id(..)}', $redux:pattern)"/>
          </alias:next-match>
        </alias:otherwise>
      </alias:choose>
    </alias:template>
  </xsl:template>

  <xsl:template match="sch:assert" as="element(xsl:if)" mode="transpile">
    <alias:if test="not({@test})">
      <svrl:failed-assert>
        <xsl:sequence select="@flag"/>
        <xsl:sequence select="@id"/>
        <xsl:sequence select="@role"/>
        <xsl:sequence select="@test"/>
        <xsl:attribute name="xml:lang" select="redux:in-scope-language(.)"/>
        <alias:attribute name="location" select="redux:location(.)"/>
        <xsl:call-template name="report-diagnostics"/>
        <xsl:call-template name="report-properties"/>
        <xsl:call-template name="report-message"/>
      </svrl:failed-assert>
    </alias:if>
  </xsl:template>

  <xsl:template match="sch:report" as="element(xsl:if)" mode="transpile">
    <alias:if test="{@test}">
      <svrl:successful-report>
        <xsl:sequence select="@flag"/>
        <xsl:sequence select="@id"/>
        <xsl:sequence select="@role"/>
        <xsl:sequence select="@test"/>
        <xsl:attribute name="xml:lang" select="redux:in-scope-language(.)"/>
        <alias:attribute name="location" select="redux:location(.)"/>
        <xsl:call-template name="report-diagnostics"/>
        <xsl:call-template name="report-properties"/>
        <xsl:call-template name="report-message"/>
      </svrl:successful-report>
    </alias:if>
  </xsl:template>

  <xsl:template name="report-diagnostics" as="element(svrl:diagnostic-reference)*">
    <xsl:variable name="context" as="element()" select="."/>
    <xsl:for-each select="tokenize(normalize-space(@diagnostics), '\s+')">
      <svrl:diagnostic-reference diagnostic="{.}">
        <xsl:variable name="diagnostic" as="element(sch:diagnostic)"
                      select="(key('diagnosticById', ., $context/ancestor::sch:pattern), key('diagnosticById', ., $context/ancestor::sch:schema))[1]"/>
        <xsl:sequence select="$diagnostic/@xml:*"/>
        <xsl:sequence select="$diagnostic/@see"/>
        <xsl:sequence select="$diagnostic/@icon"/>
        <xsl:sequence select="$diagnostic/@fpi"/>
        <svrl:text>
          <xsl:apply-templates select="$diagnostic/node()" mode="message-content"/>
        </svrl:text>
      </svrl:diagnostic-reference>
    </xsl:for-each>
  </xsl:template>

  <xsl:template name="report-properties" as="element(svrl:property-reference)*">
    <xsl:variable name="context" as="element()" select="."/>
    <xsl:for-each select="tokenize(normalize-space(@properties), '\s+')">
      <svrl:property-reference property="{.}">
        <xsl:variable name="property" as="element(sch:property)"
                      select="(key('propertyById', ., $context/ancestor::sch:pattern), key('propertyById', ., $context/ancestor::sch:schema))[1]"/>
        <xsl:sequence select="$property/@role"/>
        <xsl:sequence select="$property/@scheme"/>
        <svrl:text>
          <xsl:sequence select="$property/@xml:*"/>
          <xsl:sequence select="$property/@see"/>
          <xsl:sequence select="$property/@icon"/>
          <xsl:sequence select="$property/@fpi"/>
          <xsl:apply-templates select="$property/node()" mode="message-content"/>
        </svrl:text>
      </svrl:property-reference>
    </xsl:for-each>
  </xsl:template>

  <xsl:template name="report-message">
    <xsl:if test="text() | *">
      <svrl:text>
        <xsl:sequence select="@xml:*"/>
        <xsl:apply-templates select="node()" mode="message-content"/>
      </svrl:text>
    </xsl:if>
  </xsl:template>

  <xsl:template match="*" mode="message-content">
    <alias:element namespace="{namespace-uri(.)}" name="{local-name(.)}">
      <xsl:sequence select="@*"/>
      <xsl:apply-templates select="node()" mode="#current"/>
    </alias:element>
  </xsl:template>

  <xsl:template match="comment() | processing-instruction()" mode="message-content">
    <xsl:sequence select="."/>
  </xsl:template>

  <xsl:template match="xsl:copy-of[ancestor::sch:property]" mode="message-content">
    <xsl:sequence select="."/>
  </xsl:template>

  <xsl:template match="sch:name[@path]" mode="message-content">
    <alias:value-of select="{@path}"/>
  </xsl:template>

  <xsl:template match="sch:name[not(@path)]" mode="message-content">
    <alias:value-of select="name()"/>
  </xsl:template>

  <xsl:template match="sch:value-of" mode="message-content">
    <alias:value-of select="{@select}"/>
  </xsl:template>

  <xsl:template name="declare-variables">
    <xsl:param name="variables" as="element(sch:let)*"/>
    <xsl:param name="declName" select="'variable'" as="xs:string"/>

    <xsl:for-each select="$variables">
      <xsl:element name="{$declName}" namespace="http://www.w3.org/1999/XSL/Transform">
        <xsl:sequence select="@name"/>
        <xsl:choose>
          <xsl:when test="@value">
            <xsl:attribute name="select" select="@value"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:apply-templates select="node()" mode="variable-content"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:element>
    </xsl:for-each>
  </xsl:template>

  <xsl:template match="comment() | processing-instruction()" mode="variable-content">
    <xsl:sequence select="."/>
  </xsl:template>

  <xsl:template match="*" mode="variable-content">
    <alias:element namespace="{namespace-uri(.)}" name="{local-name(.)}">
      <xsl:sequence select="@*"/>
      <xsl:apply-templates select="node()" mode="variable-content"/>
    </alias:element>
  </xsl:template>

  <!-- Include -->
  <xsl:template match="sch:include" as="element()">
    <xsl:apply-templates select="document(@href)" mode="#current">
      <xsl:with-param name="in-scope-language" select="redux:in-scope-language(.)"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="*" mode="include expand">
    <xsl:param name="sourceLanguage" as="xs:string" select="redux:in-scope-language(.)"/>
    <xsl:variable name="inScopeLanguage" as="xs:string" select="redux:in-scope-language(.)"/>

    <xsl:copy>
      <xsl:apply-templates select="@*" mode="#current"/>
      <xsl:if test="not(@xml:lang) and not($inScopeLanguage eq $sourceLanguage)">
        <xsl:attribute name="xml:lang" select="$inScopeLanguage"/>
      </xsl:if>
      <xsl:apply-templates select="node()" mode="#current"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="comment() | processing-instruction() | text() | @*" mode="include expand">
    <xsl:sequence select="."/>
  </xsl:template>

  <xsl:template match="*" mode="copy-location-function">
    <xsl:copy>
      <xsl:sequence select="@*"/>
      <xsl:apply-templates select="node()" mode="#current"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="xsl:*" mode="copy-location-function">
    <xsl:element name="{local-name()}" namespace="http://www.w3.org/1999/XSL/Transform">
      <xsl:sequence select="@*"/>
      <xsl:apply-templates select="node()" mode="#current"/>
    </xsl:element>
  </xsl:template>

  <xsl:template match="comment() | processing-instruction() | text()" mode="copy-location-function">
    <xsl:sequence select="."/>
  </xsl:template>

  <xsl:function name="redux:in-scope-language" as="xs:string?">
    <xsl:param name="context" as="node()"/>
    <xsl:value-of select="lower-case($context/ancestor-or-self::*[@xml:lang][1]/@xml:lang)"/>
  </xsl:function>

</xsl:transform>
