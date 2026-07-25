"use strict";

function quoteRunLength(text, start) {
    let end = start;
    while (end < text.length && text[end] === '"') end++;
    return end - start;
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
            if (character === "\\") {
                index = Math.min(text.length, index + 2);
            } else {
                index++;
                if (character === '"') normalString = false;
            }
            continue;
        }

        if (character === "#") {
            const newline = text.indexOf("\n", index + 1);
            index = newline < 0 ? text.length : newline + 1;
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

module.exports = { findArrowOffsets };
