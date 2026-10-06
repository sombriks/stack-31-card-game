// game.zig
const std = @import("std");

const GameError = error{
    DeckEmpty, // nothing left on deck
    HandEmpty, // nothing left on hand
    HandFull, // unable to draw
    NoCardAt, // no such card at hand position
    DiscardPileFull, // no space left on discard pile
    WrongSuit, // card and deck suit doesn't match
    InvalidMove, // this card can not be placed on this pile
};

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
    faceUp: bool = false,

    pub fn init(suit: Suit, value: Rank) Card {
        return .{ .suit = suit, .value = value };
    }

    pub fn face(self: Card, upDown: bool) Card {
        return .{ .suit = self.suit, .value = self.value, .faceUp = upDown };
    }

    pub fn effect(self: *Card, score: u8) u8 {
        return switch (self.value) {
            .ACE => score + 1,
            .TWO => score + 2,
            .THREE => score + 3,
            .FOUR => score + 4,
            .FIVE => score + 5,
            .SIX => score + 6,
            .SEVEN => score + 7,
            .EIGHT => score + 8,
            .NINE => score + 9,
            .TEN => score + 10,
            .JACK => if (score == 0) 0 else score - 1,
            .QUEEN => 0,
            .KING => 31,
        };
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

    pub fn empty(self: *Deck) bool {
        return self.count == 0;
    }

    pub fn draw(self: *Deck) GameError!Card {
        if (self.empty()) {
            std.log.debug("deck is empty", .{});
            return GameError.DeckEmpty;
        }

        const c = self.cards[self.count - 1];
        self.cards[self.count - 1] = undefined;
        self.count -= 1;
        return c;
    }
};

const Hand = struct {
    cards: [6]Card = undefined,
    count: usize = 0,

    pub fn full(self: *Hand) bool {
        return self.count == self.cards.len;
    }

    pub fn empty(self: *Hand) bool {
        return self.count == 0;
    }

    pub fn draw(self: *Hand, deck: *Deck) GameError!void {
        if (self.full()) {
            std.log.debug("Hand is full", .{});
            return GameError.HandFull;
        }

        if (deck.empty()) {
            std.log.debug("Deck is empty", .{});
            return GameError.DeckEmpty;
        }

        self.cards[self.count] = try deck.draw();
        self.count += 1;
    }

    pub fn peek(self: *Hand, index: usize) GameError!Card {
        if (self.empty()) {
            std.log.debug("Hand is empty", .{});
            return GameError.HandEmpty;
        }

        if (self.count <= index) {
            std.log.debug("No card at position {}", .{index});
            return GameError.NoCardAt;
        }
        return self.cards[index];
    }

    pub fn place(self: *Hand, index: usize) GameError!Card {
        const c = try self.peek(index);
        var next = index + 1;
        while (next < self.count) : (next += 1) {
            self.cards[next - 1] = self.cards[next];
        }

        self.count -= 1;
        return c;
    }
};

const DiscardPile = struct {
    cards: [52]Card = undefined,
    count: usize = 0,

    pub fn full(self: *DiscardPile) bool {
        return self.cards.len == self.count;
    }

    pub fn place(self: *DiscardPile, card: Card, faceUp: bool) GameError!void {
        if (self.full()) {
            std.log.debug("Discard pile is full", .{});
            return GameError.DiscardPileFull;
        }

        self.cards[self.count] = card.face(faceUp);
        self.count += 1;
    }
};

const Player = struct {
    name: []const u8,
    hand: Hand = .{},
    quit: bool = false,
    handler: ?*const fn (self: *Player, game: *Game) GameError!bool = null,

    pub fn effect(self: *Player, game: *Game) void {
        if (self.quit) {
            return;
        }
        var handled = false;
        var maxErrors: u8 = 3;
        while (!handled) {
            if (self.handler) |h| {
                handled = h(self, game) catch false;
                if (!handled) {
                    maxErrors -= 1;
                    handled = maxErrors > 0;
                }
            } else {
                // no handler, this player just quit
                self.quit = true;
                handled = true;
            }
        }
    }
};

const SuitPile = struct {
    cards: [13]Card = undefined,
    count: usize = 0,
    score: u8 = 0,
    lastPlayer: ?*Player = null,
    suit: Suit,

    pub fn place(self: *SuitPile, player: ?*Player, cardAt: usize) GameError!void {
        if (player) |p| {
            var card = try p.hand.peek(cardAt);
            if (self.suit != card.suit) {
                std.log.debug("Suit mismatch", .{});
                return GameError.WrongSuit;
            }

            const score = card.effect(self.score);
            if ((score < 0) or (score > 31)) {
                return GameError.InvalidMove;
            }
            card = try p.hand.place(cardAt);
            card.faceUp = true;
            self.cards[self.count] = card;
            self.count += 1;
            self.score = score;
            self.lastPlayer = p;
        }
    }
};

const PileStatus = struct {
    suit: Suit,
    score: u8 = 0,
    count: usize = 0,
    player: []const u8,
};

const GameStatus = struct {
    rounds: u16,
    deck: usize,
    discarded: usize,
    piles: [4]PileStatus,
};

const Game = struct {
    discardPile: DiscardPile = .{},
    deck: Deck = .init(),
    suitPiles: [4]SuitPile = .{
        .{ .suit = .DIAMONDS },
        .{ .suit = .HEARTS },
        .{ .suit = .CLUBS },
        .{ .suit = .SPADES },
    },
    lastRound: u16 = 0,
    players: []Player,

    pub fn status(self: *Game) GameStatus {
        var piles: [4]PileStatus = undefined;
        var i: usize = 0;
        while (i < piles.len) : (i += 1) {
            piles[i].suit = self.suitPiles[i].suit;
            piles[i].count = self.suitPiles[i].count;
            piles[i].score = self.suitPiles[i].score;
            if (self.suitPiles[i].lastPlayer) |p| {
                piles[i].player = p.name;
            } else {
                piles[i].player = "-";
            }
        }

        return .{
            .piles = piles,
            .deck = self.deck.count,
            .rounds = self.lastRound,
            .discarded = self.discardPile.count,
        };
    }

    /// a simplified end game verification
    pub fn finished(self: *Game) bool {
        return self.deck.empty() or for(self.suitPiles) |p| {
            if(p.score != 31) break false;
        } else true;
    }

    pub fn nextTurn(self: *Game) void {
        for (self.players) |*p| {
            p.effect(self);
        }
        self.lastRound += 1;
    }
};

pub fn main(_: std.process.Init) !void {}

/// helper for the random thing
fn mkRandom(io: std.Io) std.Random {
    var buf: [8]u8 = undefined;
    io.random(&buf);
    const seed = std.mem.readInt(u64, &buf, .big);
    var prng = std.Random.DefaultPrng.init(seed);
    return prng.random();
}

/// player handler which just draw and discards. for testing purposes
fn drawDiscard(p: *Player, g: *Game) GameError!bool {
    if (p.hand.full()) {
        try g.discardPile.place(try p.hand.place(0), true);
    } else {
        try p.hand.draw(&g.deck);
    }
    return true;
}

/// this one plays diamonds only
fn playDiamonds(p: *Player, g: *Game) GameError!bool {
    if (p.hand.empty()) {
        try p.hand.draw(&g.deck);
    } else {
        const c = try p.hand.peek(0);
        if (c.suit == .DIAMONDS) {
            for (&g.suitPiles) |*pile| {
                if (pile.suit == .DIAMONDS) {
                    pile.place(p, 0) catch try g.discardPile
                        .place(try p.hand
                        .place(0), true);
                }
            }
        } else {
            try g.discardPile.place(try p.hand.place(0), true);
        }
    }
    return true;
}

test "check card effects" {
    var card = Card{ .suit = .HEARTS, .value = .ACE };
    var v = card.effect(0);
    try std.testing.expectEqual(1, v);
    card.value = .TEN;
    v = card.effect(5);
    try std.testing.expectEqual(15, v);
    card.value = .JACK;
    v = card.effect(31);
    try std.testing.expectEqual(30, v);
}

test "check discard pile" {
    const card = Card{ .suit = .HEARTS, .value = .ACE };
    var trash: DiscardPile = .{};
    try std.testing.expectEqual(false, trash.full());
    _ = try trash.place(card, false);
    try std.testing.expectEqual(false, trash.full());
    try std.testing.expectEqual(1, trash.count);
}

test "should play some rounds" {
    const random = mkRandom(std.testing.io);

    var players = [_]Player{
        .{ .name = "Alice" },
        .{ .name = "Bob", .handler = &playDiamonds },
        .{ .name = "Charlene", .handler = &drawDiscard },
    };

    var game: Game = .{ .players = &players };
    game.deck.shuffle(random);
    while (!game.finished()) {
        game.nextTurn();
    }
    const s = game.status();
    std.debug.print("Round: {}\n", .{s.rounds});
    std.debug.print("Cards remaining: {}\n", .{s.deck});
    std.debug.print("Cards discarded: {}\n", .{s.discarded});
    for (s.piles) |p| {
        std.debug.print("Pile {any}, Count {any}, Score {any}, Player {s}\n", .{ p.suit, p.count, p.score, p.player });
    }
    for (game.players) |p| {
        std.debug.print("Player {s}, hand {}, quit {}\n", .{ p.name, p.hand.count, p.quit });
    }
    try std.testing.expectEqual(true, game.finished());
}
