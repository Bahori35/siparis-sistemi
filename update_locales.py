import re

path = 'mobile/lib/services/app_localizations.dart'
with open(path, 'r', encoding='utf-8') as f:
    text = f.read()

def repl(m):
    prefix_line = m.group(0)
    if 'İptal Nedeni' in prefix_line:
        return prefix_line + "\n      'default_cancel_reason': 'Dükkan tarafından iptal edildi.',"
    elif 'Abbestellung' in prefix_line or 'Stornierung' in prefix_line:
        return prefix_line + "\n      'default_cancel_reason': 'Vom Geschäft storniert.',"
    elif 'سبب الإلغاء' in prefix_line:
        return prefix_line + "\n      'default_cancel_reason': 'تم الإلغاء من قبل المتجر.',"
    elif 'Причина отмены' in prefix_line:
        return prefix_line + "\n      'default_cancel_reason': 'Отменено магазином.',"
    elif "Motif" in prefix_line:
        return prefix_line + "\n      'default_cancel_reason': 'Annulé par le magasin.',"
    else:
        return prefix_line + "\n      'default_cancel_reason': 'Cancelled by the shop.',"

new_text = re.sub(r"[ ]+'cancel_reason_prefix': '[^']+',", repl, text)

with open(path, 'w', encoding='utf-8') as f:
    f.write(new_text)

print('app_localizations.dart updated successfully!')
