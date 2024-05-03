import { APIError, type APIHandler } from './helpers/endpoint'
import {
  createSupabaseDirectClient,
  SupabaseTransaction,
} from 'shared/supabase/init'
import { createLoanIncomeNotification } from 'shared/create-notification'
import { User } from 'common/user'
import { Contract } from 'common/contract'
import { log, writeAsync } from 'shared/utils'
import { Bet } from 'common/bet'
import { PortfolioMetrics } from 'common/portfolio-metrics'
import { groupBy, uniq } from 'lodash'
import { getUserLoanUpdates, isUserEligibleForLoan } from 'common/loans'
import * as admin from 'firebase-admin'
import * as dayjs from 'dayjs'
import { LoanTxn } from 'common/txn'
import { runTxnFromBank } from 'shared/txn/run-txn'

export const requestloan: APIHandler<'request-loan'> = async (_, auth) => {
  const firestore = admin.firestore()
  const pg = createSupabaseDirectClient()

  const portfolioMetric = await pg.oneOrNone(
    `select user_id, ts, investment_value, balance, total_deposits
     from user_portfolio_history
     where user_id = $1
     order by ts desc limit 1`,
    [auth.uid],
    (r) =>
      ({
        userId: r.user_id as string,
        timestamp: Date.parse(r.ts as string),
        investmentValue: parseFloat(r.investment_value as string),
        balance: parseFloat(r.balance as string),
        totalDeposits: parseFloat(r.total_deposits as string),
      } as PortfolioMetrics)
  )
  if (!portfolioMetric) {
    throw new APIError(404, `No portfolio found for user ${auth.uid}`)
  }
  log(`Loaded portfolio.`)

  if (!isUserEligibleForLoan(portfolioMetric)) {
    throw new APIError(400, `User ${auth.uid} is not eligible for a loan`)
  }

  const user = await pg.oneOrNone<User>(
    `select data from users where id = $1 limit 1`,
    [auth.uid],
    (r) => r.data
  )
  if (!user) {
    throw new APIError(404, `User ${auth.uid} not found`)
  }
  log(`Loaded user ${user.id}`)

  const bets = await pg.map<Bet>(
    `
        select contract_bets.data from contract_bets
         join contracts on contract_bets.contract_id = contracts.id
        where contracts.resolution is null
        and contract_bets.user_id = $1
        order by contract_bets.created_time
    `,
    [auth.uid],
    (r) => r.data
  )
  log(`Loaded ${bets.length} bets.`)

  const contracts = await pg.map<Contract>(
    `select data from contracts
    where contracts.resolution is null
    and contracts.id = any($1)
  `,
    [uniq(bets.map((b) => b.contractId))],
    (r) => r.data
  )
  log(`Loaded ${contracts.length} contracts.`)

  const contractsById = Object.fromEntries(
    contracts.map((contract) => [contract.id, contract])
  )
  const betsByUser = groupBy(bets, (bet) => bet.userId)

  const userContractBets = groupBy(
    betsByUser[user.id] ?? [],
    (b) => b.contractId
  )

  const result = getUserLoanUpdates(userContractBets, contractsById)
  const { updates, payout } = result
  if (payout < 1) {
    throw new APIError(400, `User ${auth.uid} is not eligible for a loan`)
  }

  return await pg.tx(async (tx) => {
    await payUserLoan(user.id, payout, tx)
    await createLoanIncomeNotification(user, payout)

    const userBetUpdates = updates.map((update) => ({
      doc: firestore
        .collection('contracts')
        .doc(update.contractId)
        .collection('bets')
        .doc(update.betId),
      fields: {
        loanAmount: update.loanTotal,
      },
    }))

    const betUpdates = userBetUpdates.flat()
    await writeAsync(firestore, betUpdates)
    log(`Paid out ${payout} to user ${user.id}.`)

    return { payout }
  })
}

const payUserLoan = async (
  userId: string,
  payout: number,
  tx: SupabaseTransaction
) => {
  const startOfDay = dayjs().tz('America/Los_Angeles').startOf('day').valueOf()

  // make sure we don't already have a txn for this user/questType
  const count = await tx.one<number>(
    `select count(*) from txns
    where data->>'toId' = $1
    and data->>'category' = 'LOAN'
    and data->'createdTime' >= $2
    limit 1`,
    [userId, startOfDay]
  )

  if (count) {
    throw new APIError(400, 'Already awarded loan today')
  }

  const loanTxn: Omit<LoanTxn, 'fromId' | 'id' | 'createdTime'> = {
    fromType: 'BANK',
    toId: userId,
    toType: 'USER',
    amount: payout,
    token: 'M$',
    category: 'LOAN',
    data: {
      // Distinguishes correct loans from erroneous old loans that were marked as deposits instead of profit.
      countsAsProfit: true,
    },
  }
  await runTxnFromBank(tx, loanTxn, true)
}
