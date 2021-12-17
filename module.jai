// Parses the given csv string into an array of T
// The get_member function is called once for each column.
// It gets passed column title, index and get_member_data and should return the name of the member of T that the column should be parsed into.
// @ToDo: Use macro instead of get_member function?
csv_parse :: (csv_data: string, $T: Type, get_member_data: $U, get_member: (string, int, U) -> string, delimiter : u8 = #char ",") -> [..] T, success: bool {
	remaining_data := csv_data;
	results: [..] T;

	info := type_info(T);
	column_members: [..] *Type_Info_Struct_Member;
	defer array_free(column_members);

	last := false;
	success: bool;
	while !last {
		name: string = ---;
		name, success, last = csv_consume_col(*remaining_data, delimiter);
		if !success {
			report_error("Could not read column % of first line", column_members.count + 1);
			return results, false;
		}
		member_name := get_member(name, column_members.count, get_member_data);
		member: *Type_Info_Struct_Member;
		if member_name {
			member = get_field(info, member_name);
			if !member {
				report_error("Type % does not contain a member named \"%\"", T, member_name);
				return results, false;
			}
			// @ToDo: Support int, float, …
			if member.type.type != Type_Info_Tag.STRING {
				report_error("Member \"%\" has unsupported type %", member_name, member.type);
				return results, false;
			}
		}
		array_add(*column_members, member);
	}

	while true {
		if !remaining_data	break;

		result: T;
		line_start := remaining_data;

		for column_members {
			// @Speed: Skip col if we’re not interested (instead of potentially un-quoting)
			val, success, last := csv_consume_col(*remaining_data, delimiter);
			if !success || (last && it_index != column_members.count - 1) {
				report_error("Could not read column % of line %:\n%", it_index + 1, results.count + 2, line_start);
				return results, false;
			}
			if it {
				slot := (cast(*u8) *result) + it.offset_in_bytes;
				<< (cast(*string) slot) = copy_string(val);
			}
		}
		array_add(*results, result);
	}

	return results, true;
}

csv_consume_col :: (remaining_data: *string, delimiter: u8) -> col: string, success: bool, last: bool {
	if !remaining_data.count	return "", true, true;
	
	num_quotes := 0;
	delim_pos := -1;
	last := false;
	for index: 0..remaining_data.count-1 {
		c := (<<remaining_data)[index];
		if c == #char "\"" {
			num_quotes += 1;
		} else if num_quotes % 2 == 0 {
			if c == delimiter {
				delim_pos = index;
				break;
			} else if c == #char "\n" {
				delim_pos = index;
				last = true;
				break;
			}
		}
	}
	col, remainder: string;
	if delim_pos == -1 {
		col = <<remaining_data;
		remaining_data.count = 0;
		last = true;
	} else {
		col = slice(<<remaining_data, 0, delim_pos);
		advance(remaining_data, delim_pos + 1);
	}

	if num_quotes == 0		return col, true, last;

	if num_quotes % 2 != 0 || col[0] != #char "\"" || col[col.count - 1] != #char "\"" {
		report_error("Invalid number of quotes: % in %", num_quotes, col);
		return "", false, last;
	}
	expected_len := col.count - num_quotes / 2;
	result := talloc_string(expected_len);
	result.count = 0;
	for index: 1..col.count-2 {
		result.data[result.count] = col[index];
		result.count += 1;
		if col[index] == #char "\""  {
			if col[index + 1] != #char "\"" {
				report_error("Invalid quote sequence at % in %", index, col);
				free(result);
				return "", false, last;
			}
			index += 1;
		}
	}
	return result, true, last;
}

#scope_file

report_error :: (format: string, args: .. Any) {
    log_error(format, .. args);
}

#import "Basic";
#import "String";
#import "Text_File_Handler";

