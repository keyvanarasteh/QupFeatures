import DesignSystem
import SwiftUI

struct ClaudeCheatsheetModal: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.cupertinoColors) private var colors

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    usageLimitsSection
                    SoftDivider()
                    modelEffortSection
                    SoftDivider()
                    planComparisonSection
                    SoftDivider()
                    bestPracticesSection
                    SoftDivider()
                    quickRefSection
                }
                .padding(Theme.Spacing.lg)
            }
            .background(colors.bg)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Usage & Length Limits

    private var usageLimitsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionHeader("Usage & Length Limits", icon: "gauge.with.dots.needle.33percent")

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                labelRow("Usage Limits", detail: "How much you can interact with Claude over a time period. Resets every 5 hours (session) and weekly.")
                labelRow("Length Limits", detail: "Context window size — how much Claude can process in a single chat. Up to 1M tokens on paid plans.")
                labelRow("Key Difference", detail: "Usage = quantity over time. Length = depth of a single conversation.")
            }

            subSection("Extend Context Window") {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    bullet("Use Projects (RAG) — only loads relevant content")
                    bullet("Keep project instructions concise")
                    bullet("Remove unused project files")
                    bullet("Toggle Extended Thinking off when not needed")
                    bullet("Lower effort level for routine tasks")
                    bullet("Disable non-critical tools (web search, Research, MCP)")
                }
            }

            subSection("Automatic Context Management") {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    bullet("Requires code execution enabled")
                    bullet("Claude summarizes earlier messages when nearing context limit")
                    bullet("Full chat history preserved for reference")
                    bullet("Longer conversations using this feature consume more usage")
                }
            }
        }
    }

    // MARK: - Model, Effort & Thinking

    private var modelEffortSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionHeader("Model, Effort & Thinking", icon: "sparkle")

            subSection("Effort Levels") {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    effortRow("Low / Medium", "Routine tasks, stretches usage further")
                    effortRow("High", "Best balance of quality and speed (Default)")
                    effortRow("Extra High (xhigh)", "Long-running coding and agentic tasks — Opus 4.7+")
                    effortRow("Max", "Deepest reasoning for the most critical work")
                }
            }

            subSection("Extended Thinking") {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    bullet("Separate from effort — any combination works")
                    bullet("Shows Claude's reasoning in an expandable section")
                    bullet("Cannot be turned off on Opus 5")
                    bullet("Incomplete thoughts appear when safety systems trigger")
                }
            }

            subSection("When to Use What") {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Simple questions, general writing")
                        .font(Theme.Typography.captionEmphasized) + Text(" → Default / Low effort").font(Theme.Typography.caption).foregroundStyle(colors.mutedFg)
                    Text("Math proofs, competition coding")
                        .font(Theme.Typography.captionEmphasized) + Text(" → High effort + Thinking").font(Theme.Typography.caption).foregroundStyle(colors.mutedFg)
                    Text("Complex coding, agentic tasks")
                        .font(Theme.Typography.captionEmphasized) + Text(" → Extra High / Max").font(Theme.Typography.caption).foregroundStyle(colors.mutedFg)
                    Text("Multi-step technical problems")
                        .font(Theme.Typography.captionEmphasized) + Text(" → High/Max + Thinking").font(Theme.Typography.caption).foregroundStyle(colors.mutedFg)
                }
            }
        }
    }

    // MARK: - Plan Comparison

    private var planComparisonSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionHeader("Plan Comparison", icon: "building.columns")

            VStack(spacing: Theme.Spacing.sm) {
                planRow("Free", "Limited session usage, resets every 5 hours")
                planRow("Pro", "$20/mo — 5x Free usage, early access, Claude Code, priority traffic")
                planRow("Max 5x", "$100/mo — 5x Pro usage, newest models first")
                planRow("Max 20x", "$200/mo — 20x Pro usage, for daily heavy users")
            }

            subSection("Pro Plan Details") {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    bullet("Session limit resets every 5 hours")
                    bullet("Weekly limit across all models")
                    bullet("Usage credits available to go beyond limits")
                    bullet("Annual subscription discount available")
                }
            }

            subSection("Max Plan Details") {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    bullet("Monthly only, two tiers: 5x and 20x")
                    bullet("Two weekly limits: all models + Sonnet-only")
                    bullet("Priority access to newest features and models")
                    bullet("Prorated billing when upgrading tiers")
                }
            }
        }
    }

    // MARK: - Best Practices

    private var bestPracticesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionHeader("Best Practices", icon: "checklist")

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                numberedRow(1, "Plan conversations", "Combine related questions in one message")
                numberedRow(2, "Be specific & concise", "Clear instructions reduce back-and-forth")
                numberedRow(3, "Use memory & chat search", "Paid plans can search past conversations")
                numberedRow(4, "Batch similar requests", "Send multiple problems in one message")
                numberedRow(5, "Review before sending", "Check clarity to avoid follow-ups")
                numberedRow(6, "Use Projects", "Cached content doesn't count against limits")
                numberedRow(7, "Monitor in Settings > Usage", "Track session and weekly consumption")
                numberedRow(8, "Quick caching tips", "Upload core docs to project knowledge once")
            }

            subSection("Per-Use-Case Tips") {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Coding").font(Theme.Typography.captionEmphasized) + Text(": Provide full environment context + complete snippets in one message").font(Theme.Typography.caption).foregroundStyle(colors.mutedFg)
                    Text("Writing").font(Theme.Typography.captionEmphasized) + Text(": Outline requirements, audience, key points upfront").font(Theme.Typography.caption).foregroundStyle(colors.mutedFg)
                    Text("Research").font(Theme.Typography.captionEmphasized) + Text(": Define question + all data in a single structured message").font(Theme.Typography.caption).foregroundStyle(colors.mutedFg)
                }
            }
        }
    }

    // MARK: - Quick Reference

    private var quickRefSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionHeader("Quick Reference", icon: "clock")

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                labelRow("Session Reset", detail: "Every 5 hours")
                labelRow("Weekly Reset", detail: "Fixed day/time per account — see Settings > Usage")
                labelRow("Context Window", detail: "Up to 1M tokens (paid plans)")
                labelRow("All surfaces share limit", detail: "claude.ai + Claude Code + Claude Desktop")
            }

            subSection("Related Articles") {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    linkRow("Context Window Sizes", "support.claude.com/articles/8606394")
                    linkRow("Choose a Plan", "support.claude.com/articles/11049762")
                    linkRow("Usage Credits", "support.claude.com/articles/12429409")
                    linkRow("Projects Guide", "support.claude.com/articles/9517075")
                    linkRow("Claude Code Config", "support.claude.com/articles/11940350")
                }
            }
        }
    }

    // MARK: - Reusable Components

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(colors.primary)
            Text(title)
                .font(Theme.Typography.headline)
                .foregroundStyle(colors.fg)
        }
    }

    private func subSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title)
                .font(Theme.Typography.bodyEmphasized)
                .foregroundStyle(colors.fg)
            content()
        }
    }

    private func labelRow(_ label: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Text(label)
                .font(Theme.Typography.captionEmphasized)
                .foregroundStyle(colors.fg)
                .frame(minWidth: 100, alignment: .leading)
            Text(detail)
                .font(Theme.Typography.caption)
                .foregroundStyle(colors.mutedFg)
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.xs) {
            Text("•")
                .font(Theme.Typography.caption)
                .foregroundStyle(colors.primary)
            Text(text)
                .font(Theme.Typography.caption)
                .foregroundStyle(colors.mutedFg)
        }
    }

    private func effortRow(_ level: String, _ description: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            StatusBadge(level, tone: .info)
            Text(description)
                .font(Theme.Typography.caption)
                .foregroundStyle(colors.mutedFg)
        }
    }

    private func planRow(_ name: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            StatusBadge(name, tone: .neutral)
            Text(detail)
                .font(Theme.Typography.caption)
                .foregroundStyle(colors.mutedFg)
        }
    }

    private func numberedRow(_ number: Int, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Text("\(number).")
                .font(Theme.Typography.captionEmphasized)
                .foregroundStyle(colors.primary)
                .frame(width: 20, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(Theme.Typography.captionEmphasized)
                    .foregroundStyle(colors.fg)
                Text(detail)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(colors.mutedFg)
            }
        }
    }

    private func linkRow(_ title: String, _ url: String) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: "arrow.up.forward.square")
                .font(Theme.Typography.caption)
                .foregroundStyle(colors.primary)
            Text(title)
                .font(Theme.Typography.caption)
                .foregroundStyle(colors.primary)
            Text(url)
                .font(Theme.Typography.caption)
                .foregroundStyle(colors.mutedFg)
        }
    }
}
