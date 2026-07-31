import Foundation
import DynamicPagesAPI
import DynamicUI

/// Encode/decode helpers between editor JSON text and API body maps.
public enum DynamicPageBodyCodec {
    public enum CodecError: LocalizedError, Sendable {
        case empty
        case invalidUTF8
        case notObject
        case document(String)

        public var errorDescription: String? {
            switch self {
            case .empty: return "Body JSON is empty."
            case .invalidUTF8: return "Body is not valid UTF-8."
            case .notObject: return "Body must be a JSON object (DynamicDocument)."
            case .document(let message): return message
            }
        }
    }

    /// Pretty-print a page body map for the editor.
    public static func prettyJSON(from body: [String: DynamicPageJSONValue]?) throws -> String {
        guard let body else {
            return Self.blankTemplate
        }
        let data = try JSONEncoder.pretty.encode(DynamicPageJSONValue.object(body))
        guard let string = String(data: data, encoding: .utf8) else {
            throw CodecError.invalidUTF8
        }
        return string
    }

    /// Validate as `DynamicDocument` and return the object map for `DynamicPageInput.body`.
    public static func parseBodyObject(_ json: String) throws -> [String: DynamicPageJSONValue] {
        let trimmed = json.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CodecError.empty }
        guard let data = trimmed.data(using: .utf8) else { throw CodecError.invalidUTF8 }

        do {
            _ = try DynamicDocument.decode(from: data)
        } catch {
            throw CodecError.document(
                (error as? LocalizedError)?.errorDescription ?? "\(error)"
            )
        }

        let value = try JSONDecoder().decode(DynamicPageJSONValue.self, from: data)
        guard case .object(let dict) = value else { throw CodecError.notObject }
        return dict
    }

    /// Returns nil when JSON is empty/whitespace (preview nothing); error string when invalid.
    public static func validationMessage(for json: String) -> String? {
        let trimmed = json.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Body is empty." }
        do {
            _ = try parseBodyObject(trimmed)
            return nil
        } catch {
            return (error as? LocalizedError)?.errorDescription ?? "\(error)"
        }
    }

    public static let blankTemplate = """
    {
      "schema_version" : 1,
      "chrome" : {
        "page_container" : true,
        "max_width" : "regular"
      },
      "root" : {
        "type" : "vstack",
        "spacing" : "md",
        "children" : [
          {
            "type" : "section_header",
            "title" : "New page",
            "subtitle" : "Edit this DynamicDocument",
            "system_image" : "doc.richtext"
          },
          {
            "type" : "text",
            "text" : "Replace this body with your layout."
          }
        ]
      }
    }
    """

    public static let demoTemplate = """
    {
      "schema_version" : 1,
      "chrome" : {
        "page_container" : true,
        "max_width" : "regular"
      },
      "root" : {
        "type" : "vstack",
        "spacing" : "md",
        "children" : [
          {
            "type" : "section_header",
            "title" : "Pages API",
            "subtitle" : "First-class DynamicDocument storage",
            "system_image" : "doc.richtext"
          },
          {
            "type" : "text",
            "text" : "Loaded via GET /pages/by-key — not menu props.ui."
          },
          {
            "type" : "grid",
            "columns" : "auto",
            "min_item_width" : 200,
            "gap" : "sm",
            "children" : [
              {
                "type" : "card",
                "children" : [
                  { "type" : "text", "text" : "Always" },
                  { "type" : "status_badge", "title" : "all widths", "tone" : "info" }
                ]
              },
              {
                "type" : "card",
                "when" : { "min_class" : "tablet" },
                "children" : [
                  { "type" : "text", "text" : "Tablet+" },
                  { "type" : "status_badge", "title" : "tablet", "tone" : "success" }
                ]
              },
              {
                "type" : "card",
                "when" : { "min_class" : "desktop" },
                "children" : [
                  { "type" : "text", "text" : "Desktop+" },
                  { "type" : "status_badge", "title" : "desktop", "tone" : "warning" }
                ]
              }
            ]
          }
        ]
      }
    }
    """

    public static let hpcTemplate = """
    {
      "schema_version" : 1,
      "chrome" : {
        "page_container" : true,
        "max_width" : "wide"
      },
      "root" : {
        "type" : "vstack",
        "spacing" : "md",
        "children" : [
          {
            "type" : "inline_section_label",
            "title" : "Cluster",
            "subtitle" : "Presentation-only HPC widgets"
          },
          {
            "type" : "hpc_status_pill",
            "title" : "Queue",
            "status" : "online",
            "subtitle" : "demo"
          },
          {
            "type" : "metric_bar",
            "title" : "CPU",
            "value" : 0.62,
            "unit" : "%"
          },
          {
            "type" : "sparkline",
            "title" : "Load",
            "points" : [0.2, 0.4, 0.35, 0.7, 0.55, 0.8]
          }
        ]
      }
    }
    """
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
