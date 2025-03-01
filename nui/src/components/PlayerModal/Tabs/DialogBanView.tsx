import React, { useState } from "react";
import {
  Alert,
  Box,
  Button,
  DialogContent,
  MenuItem,
  TextField,
  Typography,
} from "@mui/material";
import { useAssociatedPlayerValue, usePlayerDetailsValue } from "../../../state/playerDetails.state";
import { fetchWebPipe } from "../../../utils/fetchWebPipe";
import { useSnackbar } from "notistack";
import { useTranslate } from "react-polyglot";
import { usePlayerModalContext } from "../../../provider/PlayerModalProvider";
import { userHasPerm } from "../../../utils/miscUtils";
import { usePermissionsValue } from "../../../state/permissions.state";
import { DialogLoadError } from "./DialogLoadError";
import { GenericApiError, GenericApiResp } from "@shared/genericApiTypes";

const DialogBanView: React.FC = () => {
  const assocPlayer = useAssociatedPlayerValue();
  const playerDetails = usePlayerDetailsValue();
  const [reason, setReason] = useState("");
  const [duration, setDuration] = useState("2 hours");
  const [customDuration, setCustomDuration] = useState("hours");
  const [customDurLength, setCustomDurLength] = useState("1");
  const t = useTranslate();
  const { enqueueSnackbar } = useSnackbar();
  const { showNoPerms, setModalOpen } = usePlayerModalContext();
  const playerPerms = usePermissionsValue();

  if (typeof assocPlayer !== "object") {
    return <DialogLoadError />;
  }

  const onJoinCheckBan = ('meta' in playerDetails && playerDetails.meta.onJoinCheckBan);

  const handleBan = async (e) => {
    e.preventDefault();
    if (!userHasPerm("players.ban", playerPerms)) return showNoPerms("Ban");

    const trimmedReason = reason.trim();
    if (!trimmedReason.length) {
      return enqueueSnackbar(
        t("nui_menu.player_modal.ban.reason_required"),
        { variant: 'error' }
      );
    }

    const actualDuration = duration === "custom"
      ? `${customDurLength} ${customDuration}`
      : duration;
    try {
      const result = await fetchWebPipe<GenericApiResp>(`/player/ban?mutex=current&netid=${assocPlayer.id}`, {
        method: "POST",
        data: {
          reason: trimmedReason,
          duration: actualDuration,
        },
      });
      if ('success' in result && result.success === true) {
        setModalOpen(false);
        enqueueSnackbar(
          t(`nui_menu.player_modal.ban.success`),
          { variant: 'success' }
        );
      } else {
        enqueueSnackbar(
          (result as GenericApiError).error ?? t("nui_menu.misc.unknown_error"),
          { variant: 'error' }
        );
      }
    } catch (error) {
      enqueueSnackbar((error as Error).message, { variant: 'error' });
    }
  };

  const banDurations = [
    {
      value: "2 hours",
      label: `2 ${t("nui_menu.player_modal.ban.hours")}`,
    },
    {
      value: "8 hours",
      label: `8 ${t("nui_menu.player_modal.ban.hours")}`,
    },
    {
      value: "1 day",
      label: `1 ${t("nui_menu.player_modal.ban.days")}`,
    },
    {
      value: "2 days",
      label: `2 ${t("nui_menu.player_modal.ban.days")}`,
    },
    {
      value: "1 week",
      label: `1 ${t("nui_menu.player_modal.ban.weeks")}`,
    },
    {
      value: "2 weeks",
      label: `2 ${t("nui_menu.player_modal.ban.weeks")}`,
    },
    {
      value: "permanent",
      label: t("nui_menu.player_modal.ban.permanent"),
    },
    {
      value: "custom",
      label: t("nui_menu.player_modal.ban.custom"),
    },
  ];

  const customBanLength = [
    {
      value: "hours",
      label: t("nui_menu.player_modal.ban.hours"),
    },
    {
      value: "days",
      label: t("nui_menu.player_modal.ban.days"),
    },
    {
      value: "weeks",
      label: t("nui_menu.player_modal.ban.weeks"),
    },
    {
      value: "months",
      label: t("nui_menu.player_modal.ban.months"),
    },
  ];

  return (
    <DialogContent>
      <Typography variant="h6" sx={{ mb: 2 }}>{t("nui_menu.player_modal.ban.title")}</Typography>
      {!onJoinCheckBan && <Alert severity="warning" variant="outlined" sx={{ mb: 2 }}>
        <strong>Ban checking is disabled.</strong> <br />
        You need to enable it (<code>txAdmin &gt; Settings</code>) for the ban to take effect.
      </Alert>}
      <form onSubmit={handleBan}>
        <TextField
          autoFocus
          size="small"
          id="name"
          label={t("nui_menu.player_modal.ban.reason_placeholder")}
          required
          type="text"
          variant="outlined"
          fullWidth
          value={reason}
          onChange={(e) => setReason(e.currentTarget.value)}
        />
        <TextField
          size="small"
          select
          required
          sx={{ mt: 2 }}
          label={t("nui_menu.player_modal.ban.duration_placeholder")}
          variant="outlined"
          value={duration}
          onChange={(e) => setDuration(e.target.value)}
          helperText={t("nui_menu.player_modal.ban.helper_text")}
          fullWidth
        >
          {banDurations.map((option) => (
            <MenuItem key={option.value} value={option.value}>
              {option.label}
            </MenuItem>
          ))}
        </TextField>
        {duration === "custom" && (
          <Box display="flex" alignItems="center" justifyContent="center">
            <Box>
              <TextField
                type="number"
                placeholder="1"
                variant="outlined"
                size="small"
                value={customDurLength}
                onChange={(e) => setCustomDurLength(e.target.value)}
              />
            </Box>
            <Box flexGrow={1}>
              <TextField
                select
                size="small"
                variant="outlined"
                fullWidth
                value={customDuration}
                onChange={(e) => setCustomDuration(e.target.value)}
              >
                {customBanLength.map((option) => (
                  <MenuItem key={option.value} value={option.value}>
                    {option.label}
                  </MenuItem>
                ))}
              </TextField>
            </Box>
          </Box>
        )}
        <Button
          variant="contained"
          type="submit"
          color="error"
          sx={{ mt: 2 }}
          onClick={handleBan}
        >
          {t("nui_menu.player_modal.ban.submit")}
        </Button>
      </form>
    </DialogContent>
  );
};

export default DialogBanView;
