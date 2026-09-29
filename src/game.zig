// game.zig
const std = @import("std");

const Suit = enum {
    DIAMONDS, // diamonds (♦)
    HEARTS, // hearts (♥)
    CLUBS, // clubs (♣)
    SPADES, // spades (♠)
};

const CardValue = enum {
    ACE, // 1
    TWO, // 2
    THREE, // 3
    FOUR, // 4
    FIVE, // 5
    SIX, // 6
    SEVEN, // 7
    EIGHT, // 8
    NINE, // 9
    TEN, // 10
    JACK, // -1
    QUEEN, // set to zero
    KING, // completes 31
};

const Card = struct {

    suit: Suit,
    value: CardValue,
    faceUp: bool = false,

    pub fn init(suit: Suit, value: CardValue) Card {
        return .{.suit = suit, .value = value};
    }
};

const Deck = struct {};

const Player = struct {};
const Game = struct {};

pub fn main(_: std.process.Init) void {
    std.log.debug("hello world: {}", .{Card.init(.DIAMONDS,.JACK)});
}
