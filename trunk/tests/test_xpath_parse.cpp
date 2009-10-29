#ifndef PUGIXML_NO_XPATH

#include "common.hpp"

TEST(xpath_literal_parse)
{
	xml_node c;
	CHECK_XPATH_STRING(c, "'a\"b'", "a\"b");
	CHECK_XPATH_STRING(c, "\"a'b\"", "a'b");
	CHECK_XPATH_STRING(c, "\"\"", "");
	CHECK_XPATH_STRING(c, "\'\'", "");
}

TEST(xpath_literal_error)
{
	CHECK_XPATH_FAIL("\"");
	CHECK_XPATH_FAIL("\'");
}

TEST(xpath_number_parse)
{
	xml_node c;
	CHECK_XPATH_NUMBER(c, "0", 0);
	CHECK_XPATH_NUMBER(c, "123", 123);
	CHECK_XPATH_NUMBER(c, "123.456", 123.456);
	CHECK_XPATH_NUMBER(c, ".123", 0.123);
	CHECK_XPATH_NUMBER(c, "123.4567890123456789012345", 123.4567890123456789012345);
}

TEST(xpath_number_error)
{
	xml_node c;
	CHECK_XPATH_FAIL("123a");
	CHECK_XPATH_FAIL("123.a");
	CHECK_XPATH_FAIL(".123a");
}

#endif
