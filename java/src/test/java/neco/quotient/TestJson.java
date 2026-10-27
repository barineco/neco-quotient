package neco.quotient;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

final class TestJson {

    private final String text;
    private int position;

    private TestJson(String text) {
        this.text = text;
    }

    static Object parse(String text) {
        TestJson reader = new TestJson(text);
        Object value = reader.value();
        reader.skipWhitespace();
        if (reader.position != text.length()) {
            throw reader.error("trailing characters");
        }
        return value;
    }

    private Object value() {
        skipWhitespace();
        if (position >= text.length()) {
            throw error("unexpected end");
        }
        char c = text.charAt(position);
        if (c == '{') {
            return object();
        }
        if (c == '[') {
            return array();
        }
        if (c == '"') {
            return string();
        }
        if (text.startsWith("true", position)) {
            position += 4;
            return Boolean.TRUE;
        }
        if (text.startsWith("false", position)) {
            position += 5;
            return Boolean.FALSE;
        }
        if (text.startsWith("null", position)) {
            position += 4;
            return null;
        }
        throw error("unexpected character");
    }

    private Map<String, Object> object() {
        Map<String, Object> fields = new LinkedHashMap<>();
        position++;
        skipWhitespace();
        if (peek() == '}') {
            position++;
            return fields;
        }
        while (true) {
            skipWhitespace();
            if (peek() != '"') {
                throw error("object key expected");
            }
            String key = string();
            skipWhitespace();
            expect(':');
            Object value = value();
            if (fields.containsKey(key)) {
                throw error("duplicate key " + key);
            }
            fields.put(key, value);
            skipWhitespace();
            char c = next();
            if (c == '}') {
                return fields;
            }
            if (c != ',') {
                throw error("',' or '}' expected");
            }
        }
    }

    private List<Object> array() {
        List<Object> items = new ArrayList<>();
        position++;
        skipWhitespace();
        if (peek() == ']') {
            position++;
            return items;
        }
        while (true) {
            items.add(value());
            skipWhitespace();
            char c = next();
            if (c == ']') {
                return items;
            }
            if (c != ',') {
                throw error("',' or ']' expected");
            }
        }
    }

    private String string() {
        expect('"');
        StringBuilder out = new StringBuilder();
        while (true) {
            char c = next();
            if (c == '"') {
                return out.toString();
            }
            if (c < 0x20) {
                throw error("control character in string");
            }
            if (c != '\\') {
                out.append(c);
                continue;
            }
            char escape = next();
            switch (escape) {
                case '"' -> out.append('"');
                case '\\' -> out.append('\\');
                case '/' -> out.append('/');
                case 'b' -> out.append('\b');
                case 'f' -> out.append('\f');
                case 'n' -> out.append('\n');
                case 'r' -> out.append('\r');
                case 't' -> out.append('\t');
                case 'u' -> {
                    if (position + 4 > text.length()) {
                        throw error("truncated unicode escape");
                    }
                    String hex = text.substring(position, position + 4);
                    for (int i = 0; i < hex.length(); i++) {
                        if (Character.digit(hex.charAt(i), 16) < 0) {
                            throw error("invalid unicode escape");
                        }
                    }
                    out.append((char) Integer.parseInt(hex, 16));
                    position += 4;
                }
                default -> throw error("invalid escape");
            }
        }
    }

    private void skipWhitespace() {
        while (position < text.length()) {
            char c = text.charAt(position);
            if (c != ' ' && c != '\t' && c != '\n' && c != '\r') {
                return;
            }
            position++;
        }
    }

    private char peek() {
        if (position >= text.length()) {
            throw error("unexpected end");
        }
        return text.charAt(position);
    }

    private char next() {
        char c = peek();
        position++;
        return c;
    }

    private void expect(char expected) {
        if (next() != expected) {
            throw error("'" + expected + "' expected");
        }
    }

    private IllegalArgumentException error(String message) {
        return new IllegalArgumentException("json at " + position + ": " + message);
    }
}
