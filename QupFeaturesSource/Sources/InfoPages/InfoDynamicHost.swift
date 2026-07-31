import DynamicUI
import DynamicUIComponents
import DynamicUILayout
import SwiftUI

/// Shared DynamicUI install list for InfoPages (and the same pattern Theme /
/// Icon customization hosts should copy).
@MainActor
enum InfoDynamicHost {
    static let installExtensions: [DynamicNodeExtensionInstall] = [
        DynamicUILayout.install,
        DynamicUIComponents.install,
    ]
}

/// Stand-in for org/tenant-authored About (or Theme branding) copy.
/// Production hosts would load this JSON from settings/CMS/API instead of a fixture.
enum OrgAboutDynamicFixture {
    /// Sample `DynamicDocument` JSON — multi-host demo (not menu-bound).
    static let json = """
    {
      "schema_version": 1,
      "chrome": { "page_container": false, "max_width": "regular" },
      "root": {
        "type": "vstack",
        "spacing": "md",
        "children": [
          {
            "type": "eq_section_header",
            "title": "From your organization",
            "subtitle": "Server-driven region — Theme / tenant About copy uses the same host.",
            "system_image": "building.2"
          },
          {
            "type": "eq_card",
            "children": [
              {
                "type": "text",
                "text": "Customize this block per tenant: welcome blurb, support hours, or product highlights. Menus are only one host; About, Contact tips, and Icon pack descriptions share DynamicHostView."
              },
              {
                "type": "eq_badge",
                "title": "SDUI multi-host",
                "tone": "info"
              },
              {
                "type": "hstack",
                "spacing": "sm",
                "children": [
                  {
                    "type": "eq_primary_button",
                    "title": "Contact",
                    "system_image": "envelope.open",
                    "action": {
                      "type": "navigate_route",
                      "route_id": "tech.qline.info.route.contact"
                    }
                  },
                  {
                    "type": "eq_secondary_button",
                    "title": "qline.tech",
                    "action": {
                      "type": "open_url",
                      "url": "https://qline.tech"
                    }
                  }
                ]
              }
            ]
          },
          {
            "type": "eq_card",
            "when": { "min_class": "tablet" },
            "children": [
              {
                "type": "eq_section_header",
                "title": "Wider layouts",
                "subtitle": "This card only appears at tablet+ widths — same JSON on phone/Mac.",
                "system_image": "rectangle.split.2x1"
              }
            ]
          }
        ]
      }
    }
    """
}

/// Contact-page tips as an SDUI snippet (form stays native; tips are customizable).
enum ContactTipsDynamicFixture {
    static let json = """
    {
      "schema_version": 1,
      "chrome": { "page_container": false },
      "root": {
        "type": "eq_card",
        "children": [
          {
            "type": "eq_section_header",
            "title": "Helpful details",
            "subtitle": "Org-editable tips via DynamicUI",
            "system_image": "lightbulb"
          },
          {
            "type": "vstack",
            "spacing": "sm",
            "children": [
              { "type": "text", "text": "• Include your account email if this is about sign-in." },
              { "type": "text", "text": "• Mention device and OS for bug reports." },
              { "type": "text", "text": "• Avoid sharing passwords or one-time codes." }
            ]
          }
        ]
      }
    }
    """
}
