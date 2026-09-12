"use strict";

function quoteRunLength(text, start) {
    let end = start;
    while (end < text.length && text[end] === '"') end++;
    return end - start;
}

function characterLiteralEnd(text, start) {
    let index = start + 1;
    if (index >= text.length || text[index] === "\n" || text[index] === "\r") return start + 1;
    if (text[index] === "\\") {
        const escaped = text[index + 1];
        if (escaped === undefined || !"0bfnrt\\'\"".includes(escaped)) return start + 1;
        index += 2;
    } else {
        const scalar = text.codePointAt(index);
        if (text[index] === "'" || (scalar >= 0xD800 && scalar <= 0xDFFF)) return start + 1;
        index += scalar > 0xFFFF ? 2 : 1;
    }
    return index < text.length && text[index] === "'" ? index + 1 : start + 1;
}

function findArrowOffsets(text) {
    const flow = [];
    const binding = [];
    let normalString = false;
    let rawDelimiterLength = 0;
    let index = 0;

    while (index < text.length) {
        const character = text[index];

        if (rawDelimiterLength > 0) {
            if (character === '"') {
                const runLength = quoteRunLength(text, index);
                index += runLength;
                if (runLength >= rawDelimiterLength) rawDelimiterLength = 0;
            } else {
                index++;
            }
            continue;
        }

        if (normalString) {
            index++;
            if (character === '"') normalString = false;
            continue;
        }

        if (character === "#") {
            const newline = text.indexOf("\n", index + 1);
            index = newline < 0 ? text.length : newline + 1;
            continue;
        }

        if (character === "'") {
            index = characterLiteralEnd(text, index);
            continue;
        }

        if (character === '"') {
            const runLength = quoteRunLength(text, index);
            index += runLength;
            if (runLength >= 3) {
                rawDelimiterLength = runLength;
            } else {
                normalString = true;
            }
            continue;
        }

        const pair = text.slice(index, index + 2);
        if (pair === "->") {
            flow.push([index, index + 2]);
            index += 2;
            continue;
        }
        if (pair === "=>") {
            binding.push([index, index + 2]);
            index += 2;
            continue;
        }
        index++;
    }

    return { flow, binding };
}

module.exports = { characterLiteralEnd, findArrowOffsets };
