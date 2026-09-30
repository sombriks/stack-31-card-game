// game.zig
const std = @import("std");

const Suit = enum {
    DIAMONDS, // diamonds (♦)
    HEARTS, // hearts (♥)
    CLUBS, // clubs (♣)
    SPADES, // spades (♠)
};

const Rank = enum {
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
    value: Rank,

    pub fn init(suit: Suit, value: Rank) Card {
        return .{.suit = suit, .value = value};
    }
};

const Deck = struct {
    cards: [52]Card = undefined,
    count: usize = 0,

    pub fn init() Deck {
        var d = Deck{};
        inline for (std.meta.tags(Suit)) |suit| {
            inline for (std.meta.tags(Rank)) |rank| {
                d.cards[d.count] = Card.init(suit, rank);
                d.count += 1;
            }
        }
        return d;
    }

    /// Fisher–Yates shuffle
    pub fn shuffle(self: *Deck, random: std.Random) void {
        var i: usize = self.count - 1;
        while (i > 0) : (i -= 1) {
            const j = random.uintLessThan(usize, i + 1);
            const temp = self.cards[i];
            self.cards[i] = self.cards[j];
            self.cards[j] = temp;
        }
    }
};

const Hand = struct {
    cards: [6]Card = undefined,
    count: usize = 0,

    pub fn draw(self: *Hand, deck: *Deck) void {
        if (self.count == self.cards.len) {
            std.log.debug("Hand is full", .{});
            return;
        }

        if(deck.count == 0) {
            std.log.debug("Deck is empty", .{});
            return;
        }

        self.cards[self.count] = deck.cards[deck.count - 1];
        self.count += 1;
        deck.count -= 1;
    }

    pub fn place() Card {

    }

    pub fn discard() Card {

    }
};

const Player = struct {};

const Game = struct {};

pub fn main(init: std.process.Init) void {
    var buf: [8]u8 = undefined;
    init.io.random(&buf);

    const seed = std.mem.readInt(u64, &buf, .big);
    var prng = std.Random.DefaultPrng.init(seed);
    const random = prng.random();
    var deck: Deck = Deck.init();
    var hand: Hand = .{};

    hand.draw(&deck);
    deck.shuffle(random);
    hand.draw(&deck);
    std.log.debug("hello world: {}", .{hand.cards[1]});
}
