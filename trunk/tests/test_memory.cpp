#include "common.hpp"

#include <string>

namespace
{
	int allocate_count = 0;
	int deallocate_count = 0;

	void* allocate(size_t size)
	{
		++allocate_count;
		return new char[size];
	}

	void deallocate(void* ptr)
	{
		++deallocate_count;
		delete[] reinterpret_cast<char*>(ptr);
	}
}

TEST(custom_memory_management)
{
	allocate_count = deallocate_count = 0;

	// remember old functions
	allocation_function old_allocate = get_memory_allocation_function();
	deallocation_function old_deallocate = get_memory_deallocation_function();

	// replace functions
	set_memory_management_functions(allocate, deallocate);

	{
		// parse document
		xml_document doc;
		CHECK(doc.load(STR("<node />")));
	
		CHECK(allocate_count == 2);
		CHECK(deallocate_count == 0);

		// modify document
		doc.child(STR("node")).set_name(STR("foobars"));

		CHECK(allocate_count == 2);
		CHECK(deallocate_count == 0);
	}

	CHECK(allocate_count == 2);
	CHECK(deallocate_count == 2);

	// restore old functions
	set_memory_management_functions(old_allocate, old_deallocate);
}

TEST(large_allocations)
{
	allocate_count = deallocate_count = 0;

	// remember old functions
	allocation_function old_allocate = get_memory_allocation_function();
	deallocation_function old_deallocate = get_memory_deallocation_function();

	// replace functions
	set_memory_management_functions(allocate, deallocate);

	{
		xml_document doc;

		CHECK(allocate_count == 1 && deallocate_count == 0);

		// initial fill
		for (size_t i = 0; i < 128; ++i)
		{
			std::basic_string<pugi::char_t> s(i * 128, 'x');

			CHECK(doc.append_child(node_pcdata).set_value(s.c_str()));
		}

		CHECK(allocate_count > 1 && deallocate_count == 0);

		// grow-prune loop
		while (doc.first_child())
		{
			pugi::xml_node node;

			// grow
			for (node = doc.first_child(); node; node = node.next_sibling())
			{
				std::basic_string<pugi::char_t> s = node.value();

				CHECK(node.set_value((s + s).c_str()));
			}

			// prune
			for (node = doc.first_child(); node; )
			{
				pugi::xml_node next = node.next_sibling().next_sibling();

				node.parent().remove_child(node);

				node = next;
			}
		}

		CHECK(allocate_count == deallocate_count + 2); // only two live pages left: one contains document node, another one waits for new allocations

		char buffer;
		CHECK(doc.load_buffer_inplace(&buffer, 0, parse_default, get_native_encoding()));

		CHECK(allocate_count == deallocate_count + 1); // only one live page left (it contains document node)
	}

	CHECK(allocate_count == deallocate_count); // everything is freed

	// restore old functions
	set_memory_management_functions(old_allocate, old_deallocate);
}
