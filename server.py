from telegram import InlineKeyboardButton, InlineKeyboardMarkup, Update
from telegram.ext import Updater, CommandHandler, CallbackQueryHandler, CallbackContext

def start(update: Update, context: CallbackContext) -> None:
    """Messaggio di benvenuto e pulsanti principali"""
    keyboard = [
        [
            InlineKeyboardButton("🆔 Ottieni Chat ID", callback_data='get_chat_id'),
            InlineKeyboardButton("ℹ️ Informazioni", callback_data='info')
        ]
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)

    welcome_message = (
        "👋 Benvenuto nel Bot di Rilevamento Cadute!\n\n"
        "Questo bot ti permetterà di ricevere notifiche in caso di rilevamento cadute.\n\n"
        "Cosa vuoi fare?"
    )

    update.message.reply_text(welcome_message, reply_markup=reply_markup)

def button_click(update: Update, context: CallbackContext) -> None:
    """Gestisce i click sui pulsanti"""
    query = update.callback_query
    query.answer()  # Risponde al callback

    if query.data == 'get_chat_id':
        chat_id = query.message.chat_id

        # Crea pulsante per copiare il chat ID
        keyboard = [
            [InlineKeyboardButton("🔄 Menu Principale", callback_data='main_menu')]
        ]
        reply_markup = InlineKeyboardMarkup(keyboard)

        message = (
            f"🆔 Il tuo Chat ID è:\n\n"
            f"`{chat_id}`\n\n"  # Il testo tra ` ` sarà formattato come codice
            "📋 Copia questo numero e inseriscilo nell'app per ricevere le notifiche."
        )

        query.edit_message_text(
            text=message,
            reply_markup=reply_markup,
            parse_mode='Markdown'  # Abilita la formattazione Markdown
        )

    elif query.data == 'info':
        keyboard = [
            [InlineKeyboardButton("🔄 Menu Principale", callback_data='main_menu')]
        ]
        reply_markup = InlineKeyboardMarkup(keyboard)

        info_message = (
            "ℹ️ *Come utilizzare questo bot:*\n\n"
            "1️⃣ Ottieni il tuo Chat ID usando il pulsante apposito\n"
            "2️⃣ Copia il numero fornito\n"
            "3️⃣ Inserisci il numero nell'app di rilevamento cadute\n"
            "4️⃣ Quando l'app rileva una caduta, riceverai una notifica qui su Telegram\n\n"
            "Per qualsiasi problema, contatta l'amministratore dell'app."
        )

        query.edit_message_text(
            text=info_message,
            reply_markup=reply_markup,
            parse_mode='Markdown'
        )

    elif query.data == 'main_menu':
        keyboard = [
            [
                InlineKeyboardButton("🆔 Ottieni Chat ID", callback_data='get_chat_id'),
                InlineKeyboardButton("ℹ️ Informazioni", callback_data='info')
            ]
        ]
        reply_markup = InlineKeyboardMarkup(keyboard)

        welcome_message = (
            "👋 Menu Principale\n\n"
            "Cosa vuoi fare?"
        )

        query.edit_message_text(
            text=welcome_message,
            reply_markup=reply_markup
        )

def main() -> None:
    """Avvia il bot"""
    # Sostituisci con il tuo token
    updater = Updater("7573422958:AAGvXJf2mAj3kYLJHLkjy-lENvnn1z_6DIc")

    # Get the dispatcher to register handlers
    dispatcher = updater.dispatcher

    # Registra i command handlers
    dispatcher.add_handler(CommandHandler("start", start))

    # Registra il callback handler per i pulsanti
    dispatcher.add_handler(CallbackQueryHandler(button_click))

    # Avvia il bot
    updater.start_polling()

    # Mantiene il bot attivo fino a Ctrl-C
    updater.idle()

if __name__ == '__main__':
    main()
