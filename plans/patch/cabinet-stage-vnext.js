(function () {
  const SUIT_SYMBOLS = { H: 'â™¥', D: 'â™¦', C: 'â™£', S: 'â™ ' };
  const RED_SUITS = new Set(['H', 'D']);
  const DEFAULT_ALL_CARD_CODES = (() => {
    const ranks = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A'];
    const suits = ['H', 'D', 'C', 'S'];
    return ranks.flatMap((rank) => suits.map((suit) => `${rank}${suit}`));
  })();

  const state = {
    slots: [],
    shuffleTimer: null,
    shuffleIndex: null,
    mode: 'idle',
    duSequence: [],
    duCurrentDealerIndex: -1,
    duPendingCarryReset: false,
    duCarryOverCard: null,
  };

  function root() {
    return document.getElementById('card-area');
  }

  function duPanel() {
    return document.getElementById('du-info-panel');
  }

  function banner() {
    return document.getElementById('lucky5-banner');
  }

  function asCard(input) {
    if (!input) return null;
    if (typeof input === 'string') {
      const code = input.toUpperCase();
      const suit = code.slice(-1);
      const rank = code.slice(0, -1);
      return { rank, suit, code };
    }
    if (input.code) return { rank: input.rank, suit: input.suit, code: input.code };
    const rank = input.rank;
    const suit = input.suit;
    return { rank, suit, code: `${rank}${suit}` };
  }

  function rankValue(card) {
    const rank = card.rank;
    const map = { A: 14, K: 13, Q: 12, J: 11 };
    return map[rank] || Number(rank);
  }

  function cardPath(card) {
    return `/assets/images/cards/${card.code}.png`;
  }

  function fallbackCardSvg(card, opts) {
    const suit = card ? card.suit : 'S';
    const rank = card ? card.rank : '';
    const fill = RED_SUITS.has(suit) ? '#d61616' : '#111111';
    const bg = opts && opts.back ? '#28435f' : '#ffffff';
    const accent = opts && opts.back ? '#94bde7' : fill;
    const symbol = opts && opts.back ? 'â˜…' : (SUIT_SYMBOLS[suit] || 'â™ ');
    const center = opts && opts.back ? 'LUCKY 5' : symbol;
    const cornerRank = opts && opts.back ? '' : rank;
    const cornerSuit = opts && opts.back ? '' : symbol;
    const svg = `
      <svg xmlns="http://www.w3.org/2000/svg" width="240" height="330" viewBox="0 0 240 330">
        <rect x="4" y="4" width="232" height="322" rx="18" fill="${bg}" stroke="#111" stroke-width="5"/>
        ${opts && opts.back ? '<rect x="24" y="24" width="192" height="282" rx="14" fill="#16324a" stroke="#9fc2ea" stroke-width="4"/>' : ''}
        <text x="24" y="46" font-size="34" font-family="Arial, sans-serif" fill="${accent}" font-weight="700">${cornerRank}</text>
        <text x="26" y="78" font-size="28" font-family="Arial, sans-serif" fill="${accent}">${cornerSuit}</text>
        <text x="120" y="180" text-anchor="middle" dominant-baseline="middle" font-size="92" font-family="Arial, sans-serif" fill="${accent}">${center}</text>
        <g transform="translate(240,330) rotate(180)">
          <text x="24" y="46" font-size="34" font-family="Arial, sans-serif" fill="${accent}" font-weight="700">${cornerRank}</text>
          <text x="26" y="78" font-size="28" font-family="Arial, sans-serif" fill="${accent}">${cornerSuit}</text>
        </g>
      </svg>`;
    return `data:image/svg+xml;charset=UTF-8,${encodeURIComponent(svg)}`;
  }

  function cardSrc(card) {
    if (!card) return fallbackCardSvg(null, { back: true });
    const path = cardPath(card);
    if (window.preloadedImages && window.preloadedImages[path]) return path;
    return fallbackCardSvg(card);
  }

  function backSrc() {
    return fallbackCardSvg(null, { back: true });
  }

  function allCardCodes() {
    return Array.isArray(window.ALL_CARD_CODES) && window.ALL_CARD_CODES.length
      ? window.ALL_CARD_CODES
      : DEFAULT_ALL_CARD_CODES;
  }

  function setIdleBackground(enabled) {
    const area = root();
    if (!area) return;
    area.classList.toggle('show-idle-brand', Boolean(enabled));
  }

  function stopShuffle() {
    if (state.shuffleTimer) {
      window.clearInterval(state.shuffleTimer);
      state.shuffleTimer = null;
    }
    state.shuffleIndex = null;
  }

  function ensureSlotCount() {
    if (state.slots.length === 5 && root().children.length === 5) return;
    initCardSlots();
  }

  function getSlot(index) {
    ensureSlotCount();
    return state.slots[index] || null;
  }

  function updateSlotLabel(index, text) {
    const slot = getSlot(index);
    if (!slot) return;
    slot.label.textContent = text || '';
  }

  function clearSlotDecorations() {
    state.slots.forEach((slot) => {
      slot.el.classList.remove('held', 'du-dealer', 'du-lucky5');
      slot.label.textContent = '';
    });
  }

  function setCardImage(index, card, opts) {
    const slot = getSlot(index);
    if (!slot) return;
    const img = slot.img;
    img.src = card ? cardSrc(card) : backSrc();
    img.alt = card ? card.code : 'Card back';
    if (opts && opts.hidden) {
      slot.el.style.opacity = '0';
    } else {
      slot.el.style.opacity = '1';
    }
  }

  function animateEntrance(slot, delayMs) {
    slot.el.style.opacity = '0';
    slot.el.style.transform = 'translateY(-60px)';
    window.setTimeout(() => {
      slot.el.style.transition = 'transform 120ms ease, opacity 120ms ease';
      slot.el.style.opacity = '1';
      slot.el.style.transform = 'translateY(0)';
    }, delayMs);
  }

  function flipReplace(slot, nextCard) {
    const img = slot.img;
    slot.el.style.transition = 'opacity 60ms ease';
    slot.el.style.opacity = '0';
    window.setTimeout(() => {
      img.src = cardSrc(nextCard);
      img.alt = nextCard.code;
      slot.el.style.transition = 'opacity 80ms ease';
      slot.el.style.opacity = '1';
    }, 60);
  }

  function createSlot(index) {
    const slot = document.createElement('div');
    slot.className = 'cab-card';
    slot.dataset.slot = String(index);

    const img = document.createElement('img');
    img.className = 'card-img';
    img.decoding = 'async';
    img.loading = 'eager';
    img.src = backSrc();
    img.alt = 'Card back';
    slot.appendChild(img);

    const label = document.createElement('div');
    label.className = 'cab-card-slot-label';
    slot.appendChild(label);

    return { el: slot, img, label };
  }

  function initCardSlots() {
    const area = root();
    if (!area) return;
    stopShuffle();
    state.slots = [];
    area.innerHTML = '';
    for (let i = 0; i < 5; i += 1) {
      const slot = createSlot(i);
      area.appendChild(slot.el);
      state.slots.push(slot);
    }
    clearSlotDecorations();
    setIdleBackground(true);
  }

  function dealCards(cardArray) {
    ensureSlotCount();
    stopShuffle();
    clearSlotDecorations();
    setIdleBackground(false);
    state.mode = 'deal';
    const cards = cardArray.map(asCard);
    cards.forEach((card, index) => {
      const slot = getSlot(index);
      setCardImage(index, card, { hidden: true });
      animateEntrance(slot, index * 100);
      updateSlotLabel(index, '');
    });
  }

  function drawCards(newCardArray, heldIndexes) {
    ensureSlotCount();
    stopShuffle();
    setIdleBackground(false);
    state.mode = 'draw';
    const held = new Set(Array.isArray(heldIndexes) ? heldIndexes : Array.from(heldIndexes || []));
    newCardArray.map(asCard).forEach((card, index) => {
      const slot = getSlot(index);
      if (held.has(index)) {
        slot.el.classList.add('held');
        return;
      }
      slot.el.classList.remove('held');
      flipReplace(slot, card);
    });
  }

  function setHold(slotIndex, isHeld) {
    const slot = getSlot(slotIndex);
    if (!slot) return;
    slot.el.classList.toggle('held', Boolean(isHeld));
    updateSlotLabel(slotIndex, isHeld ? 'HOLD' : '');
    const holdBtn = document.querySelector(`.cab-hold[data-index="${slotIndex}"]`);
    if (holdBtn) {
      holdBtn.classList.toggle('is-held', Boolean(isHeld));
      holdBtn.dataset.activeLabel = isHeld ? 'HOLD' : '';
    }
  }

  function clearAllHolds() {
    for (let i = 0; i < 5; i += 1) setHold(i, false);
  }

  function initButtonAssets() {
    const buttons = document.querySelectorAll('.cab-btn');
    buttons.forEach((button) => {
      const pressOn = () => button.classList.add('is-pressed');
      const pressOff = () => button.classList.remove('is-pressed');
      button.addEventListener('pointerdown', pressOn);
      button.addEventListener('pointerup', pressOff);
      button.addEventListener('pointerleave', pressOff);
      button.addEventListener('pointercancel', pressOff);
    });
  }

  function renderSequence(sequence, dealerIndex, revealIndex, currentStatus) {
    ensureSlotCount();
    clearSlotDecorations();
    setIdleBackground(false);
    state.slots.forEach((slot, index) => {
      const card = sequence[index] || null;
      setCardImage(index, card, { hidden: false });
      slot.el.classList.toggle('du-dealer', index === dealerIndex && Boolean(card));
      if (card && card.code === '5S') {
        slot.el.classList.add('du-lucky5');
      }
      if (!card) updateSlotLabel(index, index === revealIndex ? 'BIG / SMALL ?' : '');
      if (card && index < dealerIndex) updateSlotLabel(index, 'PLAYED');
      if (card && index === dealerIndex) updateSlotLabel(index, 'DEALER');
      if (card && currentStatus && index === dealerIndex + 1) updateSlotLabel(index, currentStatus);
    });
  }

  function beginSequentialShuffle() {
    stopShuffle();
    let sequence = state.duSequence.slice();
    if (state.duPendingCarryReset && state.duCarryOverCard) {
      sequence = [state.duCarryOverCard];
      state.duSequence = sequence.slice();
      state.duCurrentDealerIndex = 0;
      state.duPendingCarryReset = false;
    }
    const revealIndex = Math.min(sequence.length, 4);
    state.shuffleIndex = revealIndex;
    renderSequence(sequence, state.duCurrentDealerIndex, revealIndex, '');
    const codes = allCardCodes();
    let cursor = 0;
    state.shuffleTimer = window.setInterval(() => {
      const code = codes[cursor % codes.length];
      cursor += 1;
      const card = asCard(code);
      const slot = getSlot(revealIndex);
      slot.img.src = cardSrc(card);
      slot.img.alt = `${card.code} shuffle`;
    }, 80);
  }

  function enterDoubleUp(dealerCard) {
    stopShuffle();
    setIdleBackground(false);
    state.mode = 'doubleup';
    state.duSequence = [asCard(dealerCard)];
    state.duCurrentDealerIndex = 0;
    state.duPendingCarryReset = false;
    state.duCarryOverCard = null;
    if (duPanel()) duPanel().classList.add('active');
    renderSequence(state.duSequence, state.duCurrentDealerIndex, 1, '');
    beginSequentialShuffle();
  }

  function syncSequenceFromArgs(trailCards, dealerCard) {
    const trail = Array.isArray(trailCards) ? trailCards.map(asCard).filter(Boolean) : [];
    const dealer = asCard(dealerCard);
    if (!dealer) return false;
    const nextSequence = trail.concat(dealer);
    if (!nextSequence.length) return false;
    state.duSequence = nextSequence.slice(0, 5);
    state.duCurrentDealerIndex = Math.max(0, state.duSequence.length - 1);
    return true;
  }

  function updateDoubleUpTrail(trailCards, dealerCard, challengerCard, status) {
    if (Array.isArray(trailCards) && trailCards.length) {
      syncSequenceFromArgs(trailCards, dealerCard);
    }
    if (!state.duSequence.length && dealerCard) {
      enterDoubleUp(dealerCard);
    }
    if (!challengerCard) {
      beginSequentialShuffle();
      return;
    }
    stopShuffle();
    const challenger = asCard(challengerCard);
    const revealIndex = state.shuffleIndex == null ? Math.min(state.duSequence.length, 4) : state.shuffleIndex;
    const sequence = state.duSequence.slice(0, revealIndex);
    sequence[revealIndex] = challenger;
    state.duSequence = sequence.slice(0, 5);
    renderSequence(state.duSequence, state.duCurrentDealerIndex, null, status || '');
    if (challenger.code === '5S') {
      const slot = getSlot(revealIndex);
      slot.el.classList.add('du-lucky5');
      showLucky5Active();
    }
    const continuing = /win|lucky|safe|continue/i.test(status || '');
    if (continuing) {
      state.duCurrentDealerIndex = revealIndex;
      if (revealIndex >= 4) {
        state.duCarryOverCard = challenger;
        state.duPendingCarryReset = true;
      }
    }
    state.shuffleIndex = null;
  }

  function shuffleChallenger() {
    beginSequentialShuffle();
  }

  function exitDoubleUp() {
    stopShuffle();
    state.mode = 'idle';
    state.duSequence = [];
    state.duCurrentDealerIndex = -1;
    state.duPendingCarryReset = false;
    state.duCarryOverCard = null;
    if (duPanel()) duPanel().classList.remove('active');
    clearSlotDecorations();
    state.slots.forEach((slot) => {
      slot.img.src = backSrc();
      slot.img.alt = 'Card back';
    });
    setIdleBackground(true);
  }

  function showLucky5Active() {
    const area = root();
    if (!area) return;
    area.classList.add('lucky5-active');
    if (banner()) banner().classList.add('active');
    window.setTimeout(() => {
      area.classList.remove('lucky5-active');
      if (banner()) banner().classList.remove('active');
    }, 700);
  }

  function getState() {
    return {
      mode: state.mode,
      duSequence: state.duSequence.map((card) => card.code),
      duCurrentDealerIndex: state.duCurrentDealerIndex,
      duPendingCarryReset: state.duPendingCarryReset,
      duCarryOverCard: state.duCarryOverCard ? state.duCarryOverCard.code : null,
    };
  }

  window.CabinetStage = {
    initCardSlots,
    dealCards,
    drawCards,
    setHold,
    clearAllHolds,
    initButtonAssets,
    enterDoubleUp,
    updateDoubleUpTrail,
    shuffleChallenger,
    exitDoubleUp,
    showLucky5Active,
    setIdleBackground,
    getState,
    asCard,
    rankValue,
  };
})();