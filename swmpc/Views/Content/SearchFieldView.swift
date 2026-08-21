//
//  SearchFieldView.swift
//  swmpc
//
//  Created by Camille Scholtz on 21/08/2026.
//

import AppKit
import MPDKit
import SFSafeSymbols
import SwiftUI

#if os(macOS)
    /// The metrics of the search field.
    ///
    /// The height is fixed rather than measured so that content behind the
    /// field can reserve exactly the same space. Measuring it and feeding the
    /// result back into that content's layout would re-lay out the field that
    /// was being measured.
    enum SearchFieldMetrics {
        /// The height of the field itself.
        static let height: CGFloat = 34

        /// The vertical space the field occupies in total, including the gap
        /// below it.
        static let reservedHeight = height + Layout.Padding.small
    }

    /// The search field shown above a media list while a search is active.
    ///
    /// The field sits in the content column rather than in the toolbar, so
    /// that its size and styling are the app's own rather than the system
    /// search field's.
    struct SearchFieldView<Accessory: View>: View {
        /// The query being typed.
        @Binding var text: String

        /// The placeholder describing what is being searched.
        let prompt: LocalizedStringResource

        /// Called when the user dismisses the field with the escape key.
        let onCancel: () -> Void

        /// Shown at the trailing edge of the field, for the options that
        /// belong with the search itself.
        @ViewBuilder let accessory: Accessory

        var body: some View {
            HStack(spacing: Layout.Spacing.small) {
                Image(systemSymbol: .magnifyingglass)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                SearchTextField(text: $text, prompt: String(localized: prompt),
                                onCancel: onCancel)

                if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemSymbol: .xmarkCircleFill)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Clear Search"))
                }

                accessory
            }
            .padding(.horizontal, Layout.Padding.medium)
            .frame(height: SearchFieldMetrics.height)
            .glassEffect(.regular, in: .capsule)
            .padding(.horizontal, Layout.Padding.small)
            .padding(.bottom, Layout.Padding.small)
        }
    }

    /// The text field backing `SearchFieldView`.
    ///
    /// SwiftUI's `TextField` cannot express what a search field needs on
    /// macOS. Focusing it through `@FocusState` selects all of its text, the
    /// way `becomeFirstResponder` does in AppKit, and when something else in
    /// the window takes first responder the field has no way to tell that it
    /// should still be editing. Owning the `NSTextField` puts the caret at
    /// the end instead of selecting, and lets focus be taken back when
    /// nothing else claimed it.
    private struct SearchTextField: NSViewRepresentable {
        @Binding var text: String

        /// The placeholder shown while the field is empty.
        let prompt: String

        /// Called when the user presses the escape key.
        let onCancel: () -> Void

        func makeNSView(context: Context) -> NSTextField {
            let field = CaretPreservingTextField(string: text)
            field.delegate = context.coordinator
            field.placeholderString = prompt
            field.isBordered = false
            field.drawsBackground = false
            field.focusRingType = .none
            field.font = .preferredFont(forTextStyle: .body)
            field.cell?.usesSingleLineMode = true
            field.cell?.wraps = false
            field.cell?.isScrollable = true

            return field
        }

        func updateNSView(_ field: NSTextField, context: Context) {
            context.coordinator.text = $text
            context.coordinator.onCancel = onCancel

            field.placeholderString = prompt

            if field.stringValue != text {
                let caret = field.currentEditor()?.selectedRange.location
                field.stringValue = text

                if let editor = field.currentEditor(), let caret {
                    editor.selectedRange = NSRange(location: min(caret, (text as NSString).length),
                                                   length: 0)
                }
            }

            takeFocusIfUnclaimed(field)
        }

        func makeCoordinator() -> Coordinator {
            Coordinator(text: $text, onCancel: onCancel)
        }

        /// Makes the field first responder while nothing else in the window
        /// has claimed it.
        ///
        /// Focus is only ever taken back from the window itself, so clicking
        /// a row or tabbing away keeps working. What this recovers from is
        /// the window being left without a first responder at all, which is
        /// what happens when the content behind the field is replaced.
        ///
        /// - Parameter field: The field that should be editing.
        private func takeFocusIfUnclaimed(_ field: NSTextField) {
            guard let window = field.window else {
                return
            }

            let responder = window.firstResponder
            let isEditing = responder === field || responder === field.currentEditor()
            let isUnclaimed = responder == nil || responder === window

            guard !isEditing, isUnclaimed else {
                return
            }

            window.makeFirstResponder(field)
        }

        final class Coordinator: NSObject, NSTextFieldDelegate {
            var text: Binding<String>
            var onCancel: () -> Void

            init(text: Binding<String>, onCancel: @escaping () -> Void) {
                self.text = text
                self.onCancel = onCancel
            }

            func controlTextDidChange(_ notification: Notification) {
                guard let field = notification.object as? NSTextField else {
                    return
                }

                text.wrappedValue = field.stringValue
            }

            func control(_: NSControl, textView _: NSTextView,
                         doCommandBy commandSelector: Selector) -> Bool
            {
                guard commandSelector == #selector(NSResponder.cancelOperation(_:)) else {
                    return false
                }

                onCancel()

                return true
            }
        }
    }

    /// A text field that takes focus when it appears and puts the caret at
    /// the end when it does, rather than selecting everything the way AppKit
    /// does by default.
    private final class CaretPreservingTextField: NSTextField {
        override func becomeFirstResponder() -> Bool {
            let didBecomeFirstResponder = super.becomeFirstResponder()

            if didBecomeFirstResponder {
                currentEditor()?.selectedRange = NSRange(location: (stringValue as NSString).length,
                                                         length: 0)
            }

            return didBecomeFirstResponder
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()

            guard let window else {
                return
            }

            Task { @MainActor in
                window.makeFirstResponder(self)
            }
        }
    }
#endif
