//
//  RegExSyntaxView.swift
//  RegExPro
//
//  Created by Lex on 2020/4/23.
//  Copyright © 2020 Lex.sh. All rights reserved.
//

import SwiftUI
import Combine
import UIKit


fileprivate struct UITextViewWrapper: UIViewRepresentable {
    typealias UIViewType = UITextView

    @Binding var text: String
    @Binding var calculatedHeight: CGFloat
    var onDone: (() -> Void)?

    func makeUIView(context: UIViewRepresentableContext<UITextViewWrapper>) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator

        tv.isEditable = true
        tv.font = UIFont.preferredFont(forTextStyle: .body)
        tv.isSelectable = true
        tv.isUserInteractionEnabled = true
        tv.isScrollEnabled = false
        tv.backgroundColor = UIColor.clear
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        if nil != onDone {
            tv.returnKeyType = .done
        }
        tv.textStorage.delegate = syntaxHighlighter

        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: UIViewRepresentableContext<UITextViewWrapper>) {
        if uiView.text != self.text {
            uiView.text = self.text
        }
        if uiView.window != nil, !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        }
        UITextViewWrapper.recalculateHeight(view: uiView, result: $calculatedHeight)
    }

    fileprivate static func recalculateHeight(view: UIView, result: Binding<CGFloat>) {
        let newSize = view.sizeThatFits(CGSize(width: view.frame.size.width, height: CGFloat.greatestFiniteMagnitude))
        if result.wrappedValue != newSize.height {
            DispatchQueue.main.async {
                result.wrappedValue = newSize.height // !! must be called asynchronously
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(text: $text, height: $calculatedHeight, onDone: onDone)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var text: Binding<String>
        var calculatedHeight: Binding<CGFloat>
        var onDone: (() -> Void)?

        init(text: Binding<String>, height: Binding<CGFloat>, onDone: (() -> Void)? = nil) {
            self.text = text
            self.calculatedHeight = height
            self.onDone = onDone
        }

        func textViewDidChange(_ uiView: UITextView) {
            text.wrappedValue = uiView.text
            UITextViewWrapper.recalculateHeight(view: uiView, result: calculatedHeight)
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            if let onDone = self.onDone, text == "\n" {
                textView.resignFirstResponder()
                onDone()
                return false
            }
            return true
        }
    }
    
    private let syntaxHighlighter = RegExSyntaxHighlighter()
}

struct RegExTextView: View {

    private var placeholder: String
    private var onCommit: (() -> Void)?

    @Binding private var text: String
    private var internalText: Binding<String> {
        Binding<String>(get: { self.text } ) {
            self.text = $0
            self.showingPlaceholder = $0.isEmpty
        }
    }

    @State private var dynamicHeight: CGFloat = 100
    @State private var showingPlaceholder = false

    init (_ placeholder: String = "", text: Binding<String>, onCommit: (() -> Void)? = nil) {
        self.placeholder = placeholder
        self.onCommit = onCommit
        self._text = text
        self._showingPlaceholder = State<Bool>(initialValue: self.text.isEmpty)
    }

    var body: some View {
        UITextViewWrapper(text: self.internalText, calculatedHeight: $dynamicHeight, onDone: onCommit)
            .frame(minHeight: dynamicHeight, maxHeight: dynamicHeight)
            .background(placeholderView, alignment: .topLeading)
    }

    var placeholderView: some View {
        Group {
            if showingPlaceholder {
                Text(placeholder).foregroundColor(.gray)
                    .padding(.leading, 4)
                    .padding(.top, 8)
            }
        }
    }
}

#if DEBUG
struct MultilineTextField_Previews: PreviewProvider {
    static var test:String = ""//some very very very long description string to be initially wider than screen"
    static var testBinding = Binding<String>(get: { test }, set: {
//        print("New value: \($0)")
        test = $0 } )

    static var previews: some View {
        VStack(alignment: .leading) {
            Text("Description:")
            RegExTextView("Enter some text here", text: testBinding, onCommit: {
                print("Final text: \(test)")
            })
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black))
            Text("Something static here...")
            Spacer()
        }
        .padding()
    }
}
#endif

class RegExSyntaxHighlighter: NSObject, NSTextStorageDelegate {
    var fontSize: CGFloat = 16
    
    func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorage.EditActions, range editedRange: NSRange, changeInLength delta: Int) {
        
        textStorage.addAttributes([
            .font: UIFont.systemFont(ofSize: fontSize),
            .foregroundColor: UIColor.black
        ], range: NSRange(location: 0, length: textStorage.length))
        
        textStorage.string.ranges(of: #"\\[$$\w]"#, options: .regularExpression).forEach { range in
            textStorage.addAttributes([
                .foregroundColor: UIColor.red
            ], range: textStorage.string.nsRange(from: range))
        }
        
        textStorage.string.ranges(of: #"[\(\)]"#, options: .regularExpression).forEach { range in
            textStorage.addAttributes([
                .foregroundColor: UIColor(red: 0, green: 0.5, blue: 0.2, alpha: 1)
            ], range: textStorage.string.nsRange(from: range))
        }
        
        textStorage.string.ranges(of: #"(?:\{)[\d,]+(?:\})"#, options: .regularExpression).forEach { range in
            textStorage.addAttributes([
                .font: UIFont.boldSystemFont(ofSize: fontSize),
                .foregroundColor: UIColor(red: 0, green: 0.3, blue: 0, alpha: 1)
            ], range: textStorage.string.nsRange(from: range))
        }
        
        textStorage.string.ranges(of: #"[\?\*\.]"#, options: .regularExpression).forEach { range in
            textStorage.addAttributes([
                .font: UIFont.boldSystemFont(ofSize: fontSize),
                .foregroundColor: UIColor(red: 0, green: 0.3, blue: 0, alpha: 1)
            ], range: textStorage.string.nsRange(from: range))
        }
        
        textStorage.string.ranges(of: #"[\^\[\$\]]"#, options: .regularExpression).forEach { range in
            textStorage.addAttributes([
                .foregroundColor: UIColor(red: 0, green: 0, blue: 0.8, alpha: 1)
            ], range: textStorage.string.nsRange(from: range))
        }
        
    }
}


extension String {
    func nsRange(from range: Range<String.Index>) -> NSRange {
        let startPos = self.distance(from: self.startIndex, to: range.lowerBound)
        let endPos = self.distance(from: self.startIndex, to: range.upperBound)
        return NSMakeRange(startPos, endPos - startPos)
    }
}

extension String {
    func ranges(of substring: String, options: CompareOptions = [], locale: Locale? = nil) -> [Range<Index>] {
        var ranges: [Range<Index>] = []
        while let range = range(of: substring, options: options, range: (ranges.last?.upperBound ?? self.startIndex)..<self.endIndex, locale: locale) {
            ranges.append(range)
        }
        return ranges
    }
}
