// Parses the given csv string into an array of T
// The get_member function is called once for each column.
// It gets passed column title, index and get_member_data and should return the name of the member of T that the column should be parsed into.
// @ToDo: Use macro instead of get_member function?
csv_parse :: (csv_data: string, $T: Type, get_member_data: $U, get_member: (string, int, U) -> string, delimiter : u8 = #char ",") -> [..] T, success: bool {
	remaining_data := csv_data;
	results: [..] T;

	line, success := consume_next_line(*remaining_data);
	if !success {
		report_error("No header line found");
		return results, false;
	}

	info := type_info(T);
	column_members: [..] *Type_Info_Struct_Member;
	defer array_free(column_members);

	last := false;
	while !last {
		name: string;
		name, success, last, line = csv_consume_col(line, delimiter);
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
		line, success := consume_next_line(*remaining_data);
		if !success {
			break;
		}
		result: T;
		full_line := line;

		for column_members {
			val: string;
			// @Speed: Skip col if we’re not interested (instead of potentially un-quoting)
			val, success, last, line = csv_consume_col(line, delimiter);
			if !success || (last && it_index != column_members.count - 1) {
				report_error("Could not read column % of line %:\n%", it_index + 1, results.count + 2, full_line);
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

csv_consume_col :: (line: string, delimiter: u8) -> col: string, success: bool, last: bool, remainder: string {
	if !line.count	return "", true, true, line;

	num_quotes := 0;
	delim_pos := -1;
	for index: 0..line.count-1 {
		if line[index] == #char "\"" {
			num_quotes += 1;
		} else if line[index] == delimiter && num_quotes % 2 == 0 {
			delim_pos = index;
			break;
		}
	}
	col, remainder: string;
	last := false;
	if delim_pos == -1 {
		col = line;
		remainder = "";
		last = true;
	} else {
		col = slice(line, 0, delim_pos);
		remainder = advance(line, delim_pos + 1);
	}

	if num_quotes == 0		return col, true, last, remainder;

	if num_quotes % 2 != 0 || col[0] != #char "\"" || col[col.count - 1] != #char "\"" {
		report_error("Invalid number of quotes: % in %", num_quotes);
		return "", false, last, line;
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
				return "", false, last, remainder;
			}
			index += 1;
		}
	}
	return result, true, last, remainder;
}

#scope_file

report_error :: (format: string, args: .. Any) {
    logprint("csv", format, .. args);
}

#import "Basic";
#import "String";
#import "Text_File_Handler";

