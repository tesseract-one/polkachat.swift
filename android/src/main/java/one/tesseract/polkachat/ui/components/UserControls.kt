package one.tesseract.polkachat.ui.components

import androidx.compose.foundation.layout.*
import androidx.compose.material.Button
import androidx.compose.material.Text
import androidx.compose.material.TextField
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp

@Composable
fun UserControls(accountId: String, send: (String) -> Unit) {
    Column {
        val message = remember {
            mutableStateOf("")
        }
        Text(text = "Account ID: $accountId")
        Row(verticalAlignment = Alignment.CenterVertically) {
            TextField(value = message.value, onValueChange = {
                message.value = it
            })
            Spacer(modifier = Modifier.width(16.dp))
            Button(onClick = {
                send(message.value)
            }) {
                Text(
                    text = "Send",
                    maxLines = 1,
                    overflow = TextOverflow.Visible,
                    modifier = Modifier.requiredWidth(IntrinsicSize.Min)
                )
            }
        }
    }
}