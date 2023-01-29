<xsl:transform version="2.0"
               xmlns:redux="https://doi.org/10.5281/zenodo.7368576"
               xmlns:xs="http://www.w3.org/2001/XMLSchema"
               xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:function name="redux:location" as="xs:string">
    <xsl:param name="context" as="node()"/>
    <xsl:value-of>
      <xsl:for-each select="$context/ancestor::*">
        <xsl:variable name="position" as="xs:integer" select="1 + count(preceding-sibling::*)"/>
        <xsl:value-of select="concat('/Q{', namespace-uri(), '}', local-name())"/>
        <xsl:value-of select="concat('[', $position, ']')"/>
      </xsl:for-each>
      <xsl:value-of select="'/'"/>
      <xsl:choose>
        <xsl:when test="$context/self::*">
          <xsl:variable name="position" as="xs:integer" select="1 + count($context/preceding-sibling::*)"/>
          <xsl:value-of select="concat('Q{', namespace-uri($context), '}', local-name($context))"/>
          <xsl:value-of select="concat('[', $position, ']')"/>
        </xsl:when>
        <xsl:when test="$context instance of attribute()">
          <xsl:value-of select="concat('@Q{', namespace-uri($context), '}', local-name($context))"/>
        </xsl:when>
        <xsl:when test="$context instance of text()">
          <xsl:variable name="position" as="xs:integer" select="1 + count($context/preceding-sibling::text())"/>
          <xsl:value-of select="'text()'"/>
          <xsl:value-of select="concat('[', $position, ']')"/>
        </xsl:when>
        <xsl:when test="$context instance of comment()">
          <xsl:variable name="position" as="xs:integer" select="1 + count($context/preceding-sibling::comment())"/>
          <xsl:value-of select="'comment()'"/>
          <xsl:value-of select="concat('[', $position, ']')"/>
        </xsl:when>
        <xsl:when test="$context instance of processing-instruction()">
          <xsl:variable name="position" as="xs:integer" select="1 + count($context/preceding-sibling::processing-instruction())"/>
          <xsl:value-of select="'processing-instruction()'"/>
          <xsl:value-of select="concat('[', $position, ']')"/>
        </xsl:when>
      </xsl:choose>
    </xsl:value-of>
  </xsl:function>

</xsl:transform>
