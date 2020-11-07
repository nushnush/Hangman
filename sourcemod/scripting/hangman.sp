#pragma semicolon 1
#include <sourcemod>
#pragma newdecls required
#define IsValidClient(%1) ( 1 <= %1 <= MaxClients && IsClientInGame(%1) )

enum struct Letter
{
    char c;
    bool hidden;

    bool AllowedToHide()
    {
        return this.c != ' ';
    }
}

enum Returns // for future include files
{
    Return_Wrong,
    Return_Correct,
    Return_FullCorrect,
    Return_GameFail
};

Letter letters[64];
ConVar gc_MaxBlocks, gc_MaxGuess;
char answer[64], current[64];
bool isRunning;
int guessCount;

public Plugin myinfo = 
{
    name = "[SM] Hangman",
    author = "Striker14",
    description = "Just the hangman game - in steam",
    version = "1.0",
    url = "https://steamcommunity.com/id/kenmaskimmeod",
};

public void OnPluginStart() 
{
    gc_MaxBlocks = CreateConVar("sm_hangman_maxblocks", "0.5", "Maximum percentage of characters to hide, out of the sentence length.", _, true, 0.25, true, 1.0);
    gc_MaxGuess = CreateConVar("sm_hangman_maxguess", "7", "Maximum guesses for the all players to have.", _, true, 1.0, true, 7.0);
    RegAdminCmd("sm_hangman", Command_Hangman, ADMFLAG_GENERIC);
    RegAdminCmd("sm_hm", Command_Hangman, ADMFLAG_GENERIC);
    RegAdminCmd("sm_cancelhangman", Cmd_Cancel, ADMFLAG_CHEATS);
    RegAdminCmd("sm_chm", Cmd_Cancel, ADMFLAG_CHEATS);
    RegAdminCmd("sm_aborthangman", Cmd_Cancel, ADMFLAG_CHEATS);
    RegAdminCmd("sm_ahm", Cmd_Cancel, ADMFLAG_CHEATS);
}

public Action Command_Hangman(int client, int args)
{ 
    if (args < 1)
    {
        ReplyToCommand(client, "[SM] Usage: sm_hangman <sentence>");
        return Plugin_Handled;
    }

    if (isRunning)
    {
        ReplyToCommand(client, "[SM] Hangman game is currently running!");
        return Plugin_Handled;
    }

    GetCmdArgString(answer, sizeof(answer));

    if (strlen(answer) <= 3)
    {
        ReplyToCommand(client, "[SM] Word too short.");
        return Plugin_Handled;
    }

    for (int i = 0; i < strlen(answer); i++)
    {
        letters[i].c = answer[i];
        letters[i].hidden = false;
    }
    HideCharacters();
    guessCount = 7 - gc_MaxGuess.IntValue;
    isRunning = true;

    ShowActivity2(client, "[SM] ", "Started a Hangman game: '%s'.", current);
    return Plugin_Handled; 
}

public Action Cmd_Cancel(int client, int args)
{ 
    if (isRunning)
    {
        isRunning = false;
        ShowActivity2(client, "[SM] ", "Aborted Hangman game.");
        return Plugin_Handled;
    }

    PrintToChat(client, "[SM] Hangman game is not running right now.");
    return Plugin_Handled; 
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
    if (!isRunning) return Plugin_Continue;

    char message[256];
    strcopy(message, sizeof(message), sArgs);
    StripQuotes(message);
    TrimString(message);
    
    int len = strlen(message);

    if (IsValidClient(client))
    {
        if (len == 1)
        {
            CheckLetter(client, message[0]);
        }
        else if (len == strlen(answer))
        {
            if (!strcmp(message, answer))
            {
                PrintToChatAll("[SM] %N has guessed the word - '%s'.", client, answer); 
                isRunning = false;
            }
        }
    }

    return Plugin_Continue;
}

void HideCharacters()
{
    strcopy(current, sizeof(current), answer);
    int amount = RoundToCeil(gc_MaxBlocks.FloatValue * CountAllowed());
    if (amount < 1)
        amount = 1;

    for (int i = 0; i < amount; i++)
    {
        int index = GetRandomIndex();
        if (index == -1)
            break;

        current[index] = '_';
        letters[index].hidden = true;
    }
}

Returns CheckLetter(const int client, const char c)
{
    Returns status = Return_Wrong;

    for (int i = 0; i < strlen(answer); i++)
    {
        if (letters[i].c == c && letters[i].hidden)
        {
            current[i] = answer[i];
            status = Return_Correct;
        }
    }

    if (!strcmp(current, answer))
    {
        PrintToChatAll("[SM] %N has guessed the word - '%s'.", client, answer); 
        isRunning = false;
        return Return_Correct;
    }
    else 
    {
        if (status == Return_Wrong)
        {
            guessCount++;
            if (guessCount >= 7)
            {
                PrintToChatAll("[SM] You guys have failed. The word was '%s'.", answer); 
                isRunning = false;
                ShowStatus();
                return Return_GameFail;
            }
        }

        ShowStatus();
    }

    return status;
}

int GetRandomIndex() 
{
    int[] indexes = new int[strlen(answer)];
    int count;
    for (int i = 0; answer[i] != '\0'; i++)
    {
        if (letters[i].AllowedToHide() && !letters[i].hidden)
        {
            indexes[count++] = i;
        }
    }
    return (count == 0) ? -1 : indexes[GetRandomInt(0, count-1)];
} 

int CountAllowed()
{
    int count = 0;
    for (int i = 0; i < strlen(answer); i++)
    {
        if (letters[i].AllowedToHide())
        {
            count++;
        }
    }
    return count;
}

void ShowStatus()
{
    Panel panel = new Panel();
    char text[128], parts[10][32];
    ExplodeString(current, " ", parts, sizeof(parts), sizeof(parts[]));
    Format(text, sizeof(text), "Current guesses: '%s", parts[0]);

    for (int i = 1; i < sizeof(parts); i++) // making spaces more visible in games
    {
        if (!strlen(parts[i])) break;
        Format(text, sizeof(text), "%s  %s", text, parts[i]);
    }
    Format(text, sizeof(text), "%s'", text);
    panel.DrawText(text);
    panel.DrawText("Start guessing some letters, the winner might be rewarded!");

    switch(guessCount)
    {
        case 7:
        {
            panel.DrawText(" __");
            panel.DrawText("|  |");
            panel.DrawText("|  O");
            panel.DrawText("| -|-");
            panel.DrawText("|  |");
            panel.DrawText("| / \\");
            panel.DrawText("|");
            panel.DrawText("|");
        }
        case 6:
        {
            panel.DrawText(" __");
            panel.DrawText("|  |");
            panel.DrawText("|  O");
            panel.DrawText("| -|");
            panel.DrawText("|  |");
            panel.DrawText("| / \\");
            panel.DrawText("|");
            panel.DrawText("|");
        }
        case 5:
        {
            panel.DrawText(" __");
            panel.DrawText("|  |");
            panel.DrawText("|  O");
            panel.DrawText("|  |");
            panel.DrawText("|  |");
            panel.DrawText("| / \\");
            panel.DrawText("|");
            panel.DrawText("|");
        }
        case 4:
        {
            panel.DrawText(" __");
            panel.DrawText("|  |");
            panel.DrawText("|  O");
            panel.DrawText("|  |");
            panel.DrawText("|  |");
            panel.DrawText("| / ");
            panel.DrawText("|");
            panel.DrawText("|");
        }
        case 3:
        {
            panel.DrawText(" __");
            panel.DrawText("|  |");
            panel.DrawText("|  O");
            panel.DrawText("|  |");
            panel.DrawText("|  |");
            panel.DrawText("|");
            panel.DrawText("|");
            panel.DrawText("|");
        }
        case 2:
        {
            panel.DrawText(" __");
            panel.DrawText("|  |");
            panel.DrawText("|  O");
            panel.DrawText("|  |");
            panel.DrawText("|");
            panel.DrawText("|");
            panel.DrawText("|");
            panel.DrawText("|");
        }
        case 1:
        {
            panel.DrawText(" __");
            panel.DrawText("|  |");
            panel.DrawText("|  O");
            panel.DrawText("|");
            panel.DrawText("|");
            panel.DrawText("|");
            panel.DrawText("|");
            panel.DrawText("|");
        }
        case 0:
        {
            panel.DrawText(" __");
            panel.DrawText("|  |");
            panel.DrawText("|");
            panel.DrawText("|");
            panel.DrawText("|");
            panel.DrawText("|");
            panel.DrawText("|");
            panel.DrawText("|");
        }
    }
    panel.DrawItem("Exit", ITEMDRAW_CONTROL);

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidClient(i))
        {
            panel.Send(i, None, 5);
        }
    }

    delete panel;
}

public int None(Menu menu, MenuAction action, int param1, int param2) {}